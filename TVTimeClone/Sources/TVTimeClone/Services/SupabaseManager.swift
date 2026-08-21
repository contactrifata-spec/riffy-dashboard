import Foundation
import Supabase
import Auth

private let supabaseURL     = URL(string: AppConfig.supabaseURL)!
private let supabaseAnonKey = AppConfig.supabaseAnonKey

final class SupabaseManager {
    static let shared = SupabaseManager()
    private(set) var client: SupabaseClient!

    private init() {}

    func configure() {
        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
    }

    var auth: AuthClient { client.auth }

    // MARK: - Auth

    func signUp(email: String, password: String) async throws -> Session {
        try await auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await auth.signIn(email: email, password: password)
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        try await auth.signInWithIdToken(credentials: .init(
            provider: .apple,
            idToken: idToken,
            nonce: nonce
        ))
    }

    func signInWithGoogle(idToken: String, nonce: String) async throws -> Session {
        try await auth.signInWithIdToken(credentials: .init(
            provider: .google,
            idToken: idToken,
            nonce: nonce
        ))
    }

    func signOut() async throws {
        try await auth.signOut()
    }

    func currentSession() async throws -> Session? {
        try await auth.session
    }

    // MARK: - User Shows

    func fetchUserShows(userId: String) async throws -> [UserShow] {
        try await client.from("user_shows")
            .select()
            .eq("user_id", value: userId)
            .order("last_watched_at", ascending: false)
            .execute()
            .value
    }

    func upsertUserShow(_ show: UserShow) async throws {
        try await client.from("user_shows")
            .upsert(show, onConflict: "user_id,show_id")
            .execute()
    }

    func markEpisodeWatched(userId: String, showId: Int, season: Int, episode: Int) async throws {
        let record: [String: AnyJSON] = [
            "user_id": .string(userId),
            "show_id": .number(Double(showId)),
            "season_number": .number(Double(season)),
            "episode_number": .number(Double(episode))
        ]
        try await client.from("user_episodes")
            .upsert(record, onConflict: "user_id,show_id,season_number,episode_number")
            .execute()
    }

    func fetchWatchedEpisodes(userId: String, showId: Int) async throws -> Set<String> {
        struct EpisodeKey: Codable {
            let seasonNumber: Int
            let episodeNumber: Int
            enum CodingKeys: String, CodingKey {
                case seasonNumber = "season_number"
                case episodeNumber = "episode_number"
            }
        }
        let episodes: [EpisodeKey] = try await client.from("user_episodes")
            .select("season_number,episode_number")
            .eq("user_id", value: userId)
            .eq("show_id", value: showId)
            .execute()
            .value
        return Set(episodes.map { "S\($0.seasonNumber)E\($0.episodeNumber)" })
    }

    // MARK: - User Movies

    func fetchUserMovies(userId: String) async throws -> [UserMovie] {
        try await client.from("user_movies")
            .select()
            .eq("user_id", value: userId)
            .order("watched_at", ascending: false)
            .execute()
            .value
    }

    func addUserMovie(_ movie: UserMovie) async throws {
        try await client.from("user_movies")
            .upsert(movie, onConflict: "user_id,movie_id")
            .execute()
    }

    func removeUserMovie(userId: String, movieId: Int) async throws {
        try await client.from("user_movies")
            .delete()
            .eq("user_id", value: userId)
            .eq("movie_id", value: movieId)
            .execute()
    }

    // MARK: - Profile

    func fetchProfile(userId: String) async throws -> UserProfile {
        try await client.from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    func updateProfile(_ profile: UserProfile) async throws {
        try await client.from("profiles")
            .upsert(profile)
            .execute()
    }

    // MARK: - Lists

    func fetchUserLists(userId: String) async throws -> [UserList] {
        try await client.from("user_lists")
            .select()
            .eq("user_id", value: userId)
            .order("created_at")
            .execute()
            .value
    }

    func createList(userId: String, name: String) async throws {
        let record: [String: AnyJSON] = [
            "user_id": .string(userId),
            "name": .string(name)
        ]
        try await client.from("user_lists").insert(record).execute()
    }
}
