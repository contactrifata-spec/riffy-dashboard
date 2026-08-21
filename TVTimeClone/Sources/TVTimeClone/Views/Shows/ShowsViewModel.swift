import Foundation
import Combine

@MainActor
final class ShowsViewModel: ObservableObject {
    @Published var keepWatchingShows: [UserShowWithDetails] = []
    @Published var upToDateShows: [UserShowWithDetails] = []
    @Published var isLoading = false
    @Published var error: String?

    private let tmdb = TMDBService.shared
    private let supabase = SupabaseManager.shared

    func load(userId: String) async {
        isLoading = true
        error = nil
        do {
            let userShows = try await supabase.fetchUserShows(userId: userId)
            var keepWatching: [UserShowWithDetails] = []
            var upToDate: [UserShowWithDetails] = []

            try await withThrowingTaskGroup(of: UserShowWithDetails?.self) { group in
                for userShow in userShows {
                    group.addTask {
                        guard let details = try? await self.tmdb.fetchShow(id: userShow.showId) else { return nil }
                        let watchedEpisodes = (try? await self.supabase.fetchWatchedEpisodes(
                            userId: userId, showId: userShow.showId
                        )) ?? []
                        return UserShowWithDetails(userShow: userShow, tmdbShow: details, watchedEpisodes: watchedEpisodes)
                    }
                }
                for try await result in group {
                    guard let r = result else { continue }
                    let status = r.computedStatus
                    switch status {
                    case .watching:   keepWatching.append(r)
                    case .upToDate:   upToDate.append(r)
                    default: break    // finished/dropped → Profile only
                    }
                }
            }

            // Sort keep watching by last watched
            keepWatchingShows = keepWatching.sorted {
                ($0.userShow.lastWatchedAt ?? .distantPast) > ($1.userShow.lastWatchedAt ?? .distantPast)
            }
            upToDateShows = upToDate.sorted {
                $0.tmdbShow.name < $1.tmdbShow.name
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func markEpisodeWatched(userId: String, showId: Int, season: Int, episode: Int) async {
        do {
            try await supabase.markEpisodeWatched(userId: userId, showId: showId, season: season, episode: episode)
            HapticManager.success()
            await load(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Composite model

struct UserShowWithDetails: Identifiable {
    var id: String { userShow.id }
    let userShow: UserShow
    let tmdbShow: TMDBShow
    let watchedEpisodes: Set<String>

    // Determine real status by cross-referencing TMDB data
    var computedStatus: WatchStatus {
        // If show is ended/cancelled and user has seen all episodes → finished
        if tmdbShow.isEnded {
            return hasUnairedEpisodes ? .watching : .finished
        }
        // Show is returning — check if there's an unwatched aired episode
        if hasUnairedEpisodes {
            return .watching
        }
        return .upToDate
    }

    var hasUnairedEpisodes: Bool {
        nextUnwatchedEpisode != nil
    }

    // Find the next unwatched aired episode
    var nextUnwatchedEpisode: (season: Int, episode: Int, name: String)? {
        guard let seasons = tmdbShow.seasons else { return nil }
        let today = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for season in seasons.sorted(by: { $0.seasonNumber < $1.seasonNumber }) {
            guard season.seasonNumber > 0 else { continue } // skip specials
            for epNum in 1...max(1, season.episodeCount) {
                let key = "S\(season.seasonNumber)E\(epNum)"
                if !watchedEpisodes.contains(key) {
                    // Episode aired check (we optimistically include if no air date)
                    return (season.seasonNumber, epNum, "Episode \(epNum)")
                }
            }
        }
        return nil
    }

    var nextEpisodeDisplay: String {
        if let next = tmdbShow.nextEpisodeToAir {
            return "Next: \(next.displayTitle)"
        }
        if let next = nextUnwatchedEpisode {
            return "Next: S\(next.season)E\(next.episode) · \(next.name)"
        }
        return "Up to date"
    }
}
