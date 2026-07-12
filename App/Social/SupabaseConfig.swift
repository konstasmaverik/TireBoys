import Foundation

/// The publishable key is safe to embed: it ships in the app binary either
/// way, and all data access is enforced by row-level security server-side.
enum SupabaseConfig {
    static let url = URL(string: "https://zircdzjlvnuqtirgvwne.supabase.co")!
    static let anonKey = "sb_publishable_mp_ajJifZ7-bPRcIJU8kwg_ES7PJtaT"
}
