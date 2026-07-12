import PhotosUI
import SwiftUI

struct SocialView: View {
    let backend: Backend

    @State private var isSearchingFriends = false
    @State private var isCreatingGroup = false
    @State private var isJoiningGroup = false
    @State private var newGroupName = ""
    @State private var inviteCode = ""
    @State private var actionError: String?
    @State private var avatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    var body: some View {
        NavigationStack {
            Group {
                if backend.isSignedIn {
                    signedInList
                } else {
                    AuthView(backend: backend)
                }
            }
            .navigationTitle("Social")
        }
    }

    private var signedInList: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        ZStack {
                            AvatarView(
                                urlString: backend.profile?.avatarURL,
                                fallbackName: backend.profile?.username ?? "?",
                                size: 44
                            )
                            if isUploadingAvatar {
                                ProgressView()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(backend.profile?.username ?? "…")
                            .font(.headline)
                        Text("Tap the picture to change it")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Sign Out", role: .destructive) {
                        Task { try? await backend.signOut() }
                    }
                    .font(.footnote)
                }
            }

            if !backend.incomingRequests.isEmpty {
                Section("Friend requests") {
                    ForEach(backend.incomingRequests) { profile in
                        HStack(spacing: 10) {
                            AvatarView(urlString: profile.avatarURL, fallbackName: profile.username)
                            Text(profile.username)
                            Spacer()
                            Button("Accept") {
                                run { try await backend.acceptFriendRequest(from: profile.id) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section {
                ForEach(backend.friends) { friend in
                    HStack(spacing: 10) {
                        AvatarView(urlString: friend.avatarURL, fallbackName: friend.username)
                        Text(friend.username)
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            run { try await backend.removeFriendship(with: friend.id) }
                        }
                    }
                }
                ForEach(backend.outgoingRequests) { pending in
                    HStack(spacing: 10) {
                        AvatarView(urlString: pending.avatarURL, fallbackName: pending.username)
                        Text(pending.username)
                        Spacer()
                        Text("Pending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    isSearchingFriends = true
                } label: {
                    Label("Add friend", systemImage: "person.badge.plus")
                }
            } header: {
                Text("Friends")
            } footer: {
                if backend.friends.isEmpty, backend.outgoingRequests.isEmpty {
                    Text("Find friends by username to compare drives.")
                }
            }

            Section {
                ForEach(backend.groups) { group in
                    NavigationLink(value: group) {
                        Label(group.name, systemImage: "person.3")
                    }
                }
                Button {
                    isCreatingGroup = true
                } label: {
                    Label("Create group", systemImage: "plus.circle")
                }
                Button {
                    isJoiningGroup = true
                } label: {
                    Label("Join with invite code", systemImage: "envelope.open")
                }
            } header: {
                Text("Groups")
            }

            if let actionError {
                Text(actionError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationDestination(for: FriendGroup.self) { group in
            GroupDetailView(backend: backend, group: group)
        }
        .refreshable { await backend.refreshSocial() }
        .task { await backend.refreshSocial() }
        .sheet(isPresented: $isSearchingFriends) {
            FriendSearchSheet(backend: backend)
        }
        .alert("Create group", isPresented: $isCreatingGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Create") {
                let name = newGroupName.trimmingCharacters(in: .whitespaces)
                newGroupName = ""
                guard !name.isEmpty else { return }
                run { try await backend.createGroup(named: name) }
            }
            Button("Cancel", role: .cancel) { newGroupName = "" }
        }
        .alert("Join group", isPresented: $isJoiningGroup) {
            TextField("Invite code", text: $inviteCode)
            Button("Join") {
                let code = inviteCode.trimmingCharacters(in: .whitespaces)
                inviteCode = ""
                guard !code.isEmpty else { return }
                run { try await backend.joinGroup(inviteCode: code) }
            }
            Button("Cancel", role: .cancel) { inviteCode = "" }
        }
        .onChange(of: avatarItem) { _, item in
            guard let item else { return }
            uploadAvatar(item)
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem) {
        isUploadingAvatar = true
        Task {
            defer {
                isUploadingAvatar = false
                avatarItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.resized(maxDimension: 256).jpegData(compressionQuality: 0.8)
            else { return }
            do {
                try await backend.uploadAvatar(jpeg)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        actionError = nil
        Task {
            do {
                try await operation()
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}

private struct FriendSearchSheet: View {
    let backend: Backend

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Profile] = []
    @State private var requested: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(results) { profile in
                HStack {
                    Text(profile.username)
                    Spacer()
                    if requested.contains(profile.id) {
                        Text("Requested")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Add") {
                            requested.insert(profile.id)
                            Task { try? await backend.sendFriendRequest(to: profile.id) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Username")
            .task(id: query) {
                guard query.count >= 2 else {
                    results = []
                    return
                }
                try? await Task.sleep(for: .milliseconds(300))
                results = (try? await backend.searchProfiles(matching: query)) ?? []
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    SocialView(backend: Backend())
}
