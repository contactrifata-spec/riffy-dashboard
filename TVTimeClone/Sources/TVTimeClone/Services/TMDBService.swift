import Foundation

// Replace with your TMDB API key from themoviedb.org → Settings → API
private let tmdbAPIKey = "YOUR_TMDB_API_KEY"
private let baseURL = "https://api.themoviedb.org/3"

final class TMDBService {
    static let shared = TMDBService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    // MARK: - Shows

    func fetchShow(id: Int) async throws -> TMDBShow {
        try await get("/tv/\(id)", params: ["append_to_response": "seasons"])
    }

    func fetchShowDetails(id: Int) async throws -> TMDBShow {
        try await get("/tv/\(id)", params: [
            "append_to_response": "seasons,credits,similar"
        ])
    }

    func fetchSeason(showId: Int, seasonNumber: Int) async throws -> TMDBSeasonDetail {
        try await get("/tv/\(showId)/season/\(seasonNumber)")
    }

    func searchShows(query: String) async throws -> TMDBSearchResult<TMDBShow> {
        try await get("/search/tv", params: ["query": query, "include_adult": "false"])
    }

    func trendingShows(timeWindow: String = "week") async throws -> TMDBSearchResult<TMDBShow> {
        try await get("/trending/tv/\(timeWindow)")
    }

    func popularShows() async throws -> TMDBSearchResult<TMDBShow> {
        try await get("/tv/popular")
    }

    func topRatedShows() async throws -> TMDBSearchResult<TMDBShow> {
        try await get("/tv/top_rated")
    }

    func airingTodayShows() async throws -> TMDBSearchResult<TMDBShow> {
        try await get("/tv/airing_today")
    }

    // MARK: - Movies

    func fetchMovie(id: Int) async throws -> TMDBMovie {
        try await get("/movie/\(id)")
    }

    func searchMovies(query: String) async throws -> TMDBSearchResult<TMDBMovie> {
        try await get("/search/movie", params: ["query": query, "include_adult": "false"])
    }

    func trendingMovies(timeWindow: String = "week") async throws -> TMDBSearchResult<TMDBMovie> {
        try await get("/trending/movie/\(timeWindow)")
    }

    func popularMovies() async throws -> TMDBSearchResult<TMDBMovie> {
        try await get("/movie/popular")
    }

    func topRatedMovies() async throws -> TMDBSearchResult<TMDBMovie> {
        try await get("/movie/top_rated")
    }

    // MARK: - Multi Search

    func multiSearch(query: String) async throws -> [SearchResult] {
        let raw: TMDBSearchResult<RawSearchResult> = try await get("/search/multi", params: [
            "query": query,
            "include_adult": "false"
        ])
        return raw.results.compactMap { result in
            switch result.mediaType {
            case "tv":    return result.asShow.map { .show($0) }
            case "movie": return result.asMovie.map { .movie($0) }
            default:      return nil
            }
        }
    }

    // MARK: - Network helper

    private func get<T: Decodable>(_ path: String, params: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: baseURL + path)!
        var queryItems = [URLQueryItem(name: "api_key", value: tmdbAPIKey)]
        queryItems += params.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = queryItems

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Supporting types

struct TMDBSeasonDetail: Codable {
    let id: Int
    let episodes: [TMDBEpisode]
    let seasonNumber: Int

    enum CodingKeys: String, CodingKey {
        case id, episodes
        case seasonNumber = "season_number"
    }
}

enum SearchResult {
    case show(TMDBShow)
    case movie(TMDBMovie)
}

private struct RawSearchResult: Codable {
    let id: Int
    let mediaType: String
    // Show fields
    let name: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let firstAirDate: String?
    let voteAverage: Double?
    // Movie fields
    let title: String?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, title
        case mediaType = "media_type"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
    }

    var asShow: TMDBShow? {
        guard let name = name else { return nil }
        return TMDBShow(
            id: id, name: name,
            posterPath: posterPath, backdropPath: backdropPath,
            overview: overview ?? "",
            firstAirDate: firstAirDate, status: nil,
            numberOfSeasons: nil, numberOfEpisodes: nil,
            voteAverage: voteAverage ?? 0,
            genres: nil, networks: nil, seasons: nil,
            nextEpisodeToAir: nil, lastEpisodeToAir: nil
        )
    }

    var asMovie: TMDBMovie? {
        guard let title = title else { return nil }
        return TMDBMovie(
            id: id, title: title,
            posterPath: posterPath, backdropPath: backdropPath,
            overview: overview ?? "",
            releaseDate: releaseDate, runtime: nil,
            voteAverage: voteAverage ?? 0,
            genres: nil
        )
    }
}
