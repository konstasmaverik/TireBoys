import Foundation

/// Rows as they exist in Supabase. Column names map via CodingKeys so the
/// snake_case schema stays server-side.

struct Profile: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    let username: String
}

struct Friendship: Codable, Equatable {
    let requesterID: UUID
    let addresseeID: UUID
    var status: Status

    enum Status: String, Codable {
        case pending, accepted
    }

    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
    }

    func otherParty(besides userID: UUID) -> UUID {
        requesterID == userID ? addresseeID : requesterID
    }
}

struct FriendGroup: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let inviteCode: String
    let ownerID: UUID

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
        case ownerID = "owner_id"
    }
}

struct LeaderboardEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let username: String
    let totalDistanceMeters: Double
    let totalDurationSeconds: Double
    let topSpeedMetersPerSecond: Double
    let driveCount: Int

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case username
        case totalDistanceMeters = "total_distance_meters"
        case totalDurationSeconds = "total_duration_seconds"
        case topSpeedMetersPerSecond = "top_speed_mps"
        case driveCount = "drive_count"
    }
}

struct RemoteDrive: Codable {
    let id: UUID
    let userID: UUID
    let startedAt: Date
    let endedAt: Date
    let distanceMeters: Double
    let durationSeconds: Double
    let topSpeedMetersPerSecond: Double

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case distanceMeters = "distance_meters"
        case durationSeconds = "duration_seconds"
        case topSpeedMetersPerSecond = "top_speed_mps"
    }
}
