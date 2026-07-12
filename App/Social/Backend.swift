import DriveStatsCore
import Foundation
import Observation
import Supabase

/// All Supabase access lives here, mirroring how LocationService owns
/// CoreLocation: views talk to this, never to the client directly.
@MainActor
@Observable
final class Backend {
    private(set) var session: Session?
    private(set) var profile: Profile?

    private(set) var friends: [Profile] = []
    private(set) var incomingRequests: [Profile] = []
    private(set) var outgoingRequests: [Profile] = []
    private(set) var groups: [FriendGroup] = []

    private let client: SupabaseClient
    private let driveStore: JSONDriveStore?

    init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
        driveStore = try? JSONDriveStore(directory: AppPaths.drivesDirectory)
        Task { await observeAuth() }
    }

    var isSignedIn: Bool { session != nil }

    private var userID: UUID? { session?.user.id }

    private func observeAuth() async {
        for await (_, session) in client.auth.authStateChanges {
            self.session = session
            if session != nil {
                await loadProfile()
                await refreshSocial()
                await syncLocalDrives()
            } else {
                profile = nil
                friends = []
                incomingRequests = []
                outgoingRequests = []
                groups = []
            }
        }
    }

    // MARK: - Auth

    func signUp(email: String, password: String, username: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username.lowercased())]
        )
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    private func loadProfile() async {
        guard let userID else { return }
        profile = try? await client.from("profiles")
            .select().eq("id", value: userID).single()
            .execute().value
    }

    // MARK: - Friends

    func refreshSocial() async {
        guard let userID else { return }
        do {
            let friendships: [Friendship] = try await client.from("friendships")
                .select()
                .or("requester_id.eq.\(userID),addressee_id.eq.\(userID)")
                .execute().value

            let otherIDs = friendships.map { $0.otherParty(besides: userID) }
            let profiles: [Profile] = otherIDs.isEmpty ? [] : try await client.from("profiles")
                .select().in("id", values: otherIDs.map(\.uuidString))
                .execute().value
            let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            friends = friendships.filter { $0.status == .accepted }
                .compactMap { byID[$0.otherParty(besides: userID)] }
                .sorted { $0.username < $1.username }
            incomingRequests = friendships.filter { $0.status == .pending && $0.addresseeID == userID }
                .compactMap { byID[$0.requesterID] }
            outgoingRequests = friendships.filter { $0.status == .pending && $0.requesterID == userID }
                .compactMap { byID[$0.addresseeID] }

            groups = try await client.from("groups").select().order("created_at").execute().value
        } catch {
            // Pull-to-refresh retries; stale lists beat an error takeover.
        }
    }

    func searchProfiles(matching query: String) async throws -> [Profile] {
        guard let userID else { return [] }
        return try await client.from("profiles")
            .select()
            .ilike("username", pattern: "%\(query.lowercased())%")
            .neq("id", value: userID)
            .limit(10)
            .execute().value
    }

    func sendFriendRequest(to profileID: UUID) async throws {
        guard let userID else { return }
        try await client.from("friendships").insert([
            "requester_id": userID.uuidString,
            "addressee_id": profileID.uuidString,
        ]).execute()
        await refreshSocial()
    }

    func acceptFriendRequest(from requesterID: UUID) async throws {
        guard let userID else { return }
        try await client.from("friendships")
            .update(["status": "accepted"])
            .eq("requester_id", value: requesterID)
            .eq("addressee_id", value: userID)
            .execute()
        await refreshSocial()
    }

    func removeFriendship(with otherID: UUID) async throws {
        guard let userID else { return }
        try await client.from("friendships").delete()
            .or("and(requester_id.eq.\(userID),addressee_id.eq.\(otherID)),and(requester_id.eq.\(otherID),addressee_id.eq.\(userID))")
            .execute()
        await refreshSocial()
    }

    // MARK: - Groups

    func createGroup(named name: String) async throws {
        let _: FriendGroup = try await client
            .rpc("create_group", params: ["p_name": name])
            .single()
            .execute().value
        await refreshSocial()
    }

    func joinGroup(inviteCode: String) async throws {
        let _: FriendGroup = try await client
            .rpc("join_group", params: ["p_invite_code": inviteCode.lowercased()])
            .single()
            .execute().value
        await refreshSocial()
    }

    func leaveGroup(_ groupID: UUID) async throws {
        guard let userID else { return }
        try await client.from("group_members").delete()
            .eq("group_id", value: groupID)
            .eq("user_id", value: userID)
            .execute()
        await refreshSocial()
    }

    func leaderboard(for groupID: UUID, since: Date?) async throws -> [LeaderboardEntry] {
        struct Params: Encodable {
            let p_group_id: UUID
            let p_since: Date?
        }
        return try await client
            .rpc("group_leaderboard", params: Params(p_group_id: groupID, p_since: since))
            .execute().value
    }

    // MARK: - Avatar

    /// Uploads a JPEG to the avatars bucket and points the profile at it.
    /// The cache-busting query makes replacements show up immediately.
    func uploadAvatar(_ jpegData: Data) async throws {
        guard let userID else { return }
        let path = "\(userID.uuidString).jpg"
        try await client.storage.from("avatars").upload(
            path,
            data: jpegData,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        )
        let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
        let bustedURL = "\(publicURL.absoluteString)?v=\(Int(Date().timeIntervalSince1970))"
        try await client.from("profiles")
            .update(["avatar_url": bustedURL])
            .eq("id", value: userID)
            .execute()
        await loadProfile()
    }

    // MARK: - Drive sync

    /// Uploads aggregates of drives not yet synced. Route points never leave
    /// the phone. Synced ids persist so uploads happen once.
    func syncLocalDrives() async {
        guard let userID, let driveStore else { return }
        let synced = SyncedDriveIDs.load()
        guard let drives = try? driveStore.loadAll() else { return }
        let pending = drives.filter { !synced.contains($0.id) }
        guard !pending.isEmpty else { return }

        let rows = pending.map { drive in
            RemoteDrive(
                id: drive.id,
                userID: userID,
                startedAt: drive.startedAt,
                endedAt: drive.endedAt,
                distanceMeters: drive.distanceMeters,
                durationSeconds: drive.duration,
                topSpeedMetersPerSecond: max(0, drive.topSpeedMetersPerSecond)
            )
        }
        do {
            try await client.from("drives").upsert(rows).execute()
            SyncedDriveIDs.save(synced.union(pending.map(\.id)))
        } catch {
            // Offline is normal; the next launch or save retries.
        }
    }
}

/// Which local drives have already been uploaded.
private enum SyncedDriveIDs {
    private static var fileURL: URL {
        URL.documentsDirectory.appending(path: "synced-drive-ids.json")
    }

    static func load() -> Set<UUID> {
        guard let data = try? Data(contentsOf: fileURL),
              let ids = try? JSONDecoder().decode([UUID].self, from: data)
        else { return [] }
        return Set(ids)
    }

    static func save(_ ids: Set<UUID>) {
        if let data = try? JSONEncoder().encode(Array(ids)) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
