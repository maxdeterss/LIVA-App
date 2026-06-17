import Foundation

/// A 1:1 conversation (`public.conversations`).
struct Conversation: Codable, Identifiable, Hashable {
    let id: UUID
    var userA: UUID
    var userB: UUID
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userA = "user_a"
        case userB = "user_b"
        case updatedAt = "updated_at"
    }

    func otherParticipant(than me: UUID) -> UUID { userA == me ? userB : userA }
}

/// A direct message, optionally carrying a shared post (the "Send" feature).
struct Message: Codable, Identifiable, Hashable {
    let id: UUID
    var conversationID: UUID
    var senderID: UUID
    var body: String?
    var sharedPostID: UUID?
    var createdAt: Date
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case sharedPostID = "shared_post_id"
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}
