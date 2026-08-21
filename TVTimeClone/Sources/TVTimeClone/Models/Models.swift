import Foundation

// MARK: - TMDB Models

struct TMDBShow: Codable, Identifiable {
    let id: Int
    let name: String
    let posterPath: String?
    let backdropPath: String?
    let overview: String
    let firstAirDate: String?
    let status: String?       // "Returning Series", "Ended", "Canceled", "In Production"
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let voteAverage: Double
    let genres: [TMDBGenre]?
    let networks: [TMDBNetwork]?
    let seasons: [TMDBSeason]?
    let nextEpisodeToAir: TMDBEpisode?
    let lastEpisodeToAir: TMDBEpisode?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, status, genres, networks, seasons
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case voteAverage = "vote_average"
        case nextEpisodeToAir = "next_episode_to_air"
        case lastEpisodeToAir = "last_episode_to_air"
    }

    var isReturning: Bool { status == "Returning Series" || status == "In Production" }
    var isEnded: Bool { status == "Ended" || status == "Canceled" }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }
}

struct TMDBMovie: Codable, Identifiable {
    let id: Int
    let title: String
    let posterPath: String?
    let backdropPath: String?
    let overview: String
    let releaseDate: String?
    let runtime: Int?
    let voteAverage: Double
    let genres: [TMDBGenre]?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

struct TMDBGenre: Codable, Identifiable {
    let id: Int
    let name: String
}

struct TMDBNetwork: Codable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
    }
}

struct TMDBSeason: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let episodeCount: Int
    let airDate: String?
    let name: String
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case airDate = "air_date"
        case posterPath = "poster_path"
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w300\(path)")
    }
}

struct TMDBEpisode: Codable, Identifiable {
    let id: Int
    let name: String
    let episodeNumber: Int
    let seasonNumber: Int
    let airDate: String?
    let overview: String?
    let stillPath: String?
    let runtime: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case airDate = "air_date"
        case stillPath = "still_path"
    }

    var displayTitle: String { "S\(seasonNumber)E\(episodeNumber) · \(name)" }

    var stillURL: URL? {
        guard let path = stillPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w300\(path)")
    }
}

struct TMDBSearchResult<T: Codable>: Codable {
    let results: [T]
    let totalResults: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
        case totalPages = "total_pages"
    }
}

// MARK: - Supabase / User Models

struct UserShow: Codable, Identifiable {
    let id: String
    let userId: String
    let showId: Int
    let showName: String
    let posterPath: String?
    var status: WatchStatus
    var currentSeason: Int
    var currentEpisode: Int
    var totalWatchedEpisodes: Int
    var lastWatchedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case showId = "show_id"
        case showName = "show_name"
        case posterPath = "poster_path"
        case status
        case currentSeason = "current_season"
        case currentEpisode = "current_episode"
        case totalWatchedEpisodes = "total_watched_episodes"
        case lastWatchedAt = "last_watched_at"
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

enum WatchStatus: String, Codable {
    case watching      = "watching"       // has unwatched aired episodes
    case upToDate      = "up_to_date"    // fully caught up, show is returning
    case finished      = "finished"       // completed all eps, show ended/cancelled
    case dropped       = "dropped"
}

struct UserMovie: Codable, Identifiable {
    let id: String
    let userId: String
    let movieId: Int
    let movieName: String
    let posterPath: String?
    var watchedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case movieId = "movie_id"
        case movieName = "movie_name"
        case posterPath = "poster_path"
        case watchedAt = "watched_at"
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

struct UserProfile: Codable, Identifiable {
    let id: String
    var username: String?
    var displayName: String?
    var avatarUrl: String?
    var bio: String?
    var followersCount: Int
    var followingCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case followersCount = "followers_count"
        case followingCount = "following_count"
    }
}

struct UserList: Codable, Identifiable {
    let id: String
    let userId: String
    var name: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
    }
}
