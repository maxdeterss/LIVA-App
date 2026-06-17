import Foundation
import Supabase

/// Direct messages — powers the "Send" action (sharing a post to a friend).
enum MessagingService {

    /// Resolves (creating if needed) the conversation with `other`.
    static func conversation(with other: UUID) async throws -> UUID {
        let data = try await LIVA.supabase
            .rpc("get_or_create_conversation", params: ["other": other.uuidString])
            .execute().data
        return try AppJSON.decoder.decode(UUID.self, from: data)
    }

    /// Shares a post into a conversation with `recipient`.
    static func sharePost(_ postID: UUID, to recipient: UUID, note: String?) async throws {
        let convo = try await conversation(with: recipient)
        try await send(to: convo, body: note, sharedPostID: postID)
    }

    static func send(to conversation: UUID, body: String?, sharedPostID: UUID? = nil) async throws {
        guard let uid = LIVA.supabase.currentUserID else { throw AppError.notAuthenticated }
        struct Row: Encodable {
            let conversation_id: String; let sender_id: String
            let body: String?; let shared_post_id: String?
        }
        try await LIVA.supabase.from("messages")
            .insert(Row(conversation_id: conversation.uuidString, sender_id: uid.uuidString,
                        body: body, shared_post_id: sharedPostID?.uuidString))
            .execute()
    }

    static func messages(in conversation: UUID) async throws -> [Message] {
        let data = try await LIVA.supabase.from("messages").select()
            .eq("conversation_id", value: conversation.uuidString)
            .order("created_at", ascending: true)
            .execute().data
        return try AppJSON.decoder.decode([Message].self, from: data)
    }
}
