import SwiftUI

struct ShowDetailView: View {
    let showId: Int
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var showsVM: ShowsViewModel
    @State private var show: TMDBShow?
    @State private var watchedEpisodes: Set<String> = []
    @State private var isLoading = true
    @State private var expandedSeason: Int?
    @State private var seasonDetails: [Int: TMDBSeasonDetail] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if let show = show {
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero backdrop
                        HeroSection(show: show)

                        // Info
                        VStack(alignment: .leading, spacing: 20) {
                            // Rating + status chips
                            HStack(spacing: 10) {
                                if show.voteAverage > 0 {
                                    ChipView(
                                        icon: "star.fill",
                                        text: String(format: "%.1f", show.voteAverage),
                                        color: .yellow
                                    )
                                }
                                if let status = show.status {
                                    ChipView(
                                        icon: show.isReturning ? "arrow.clockwise" : "checkmark",
                                        text: status,
                                        color: show.isReturning ? AppTheme.accent : AppTheme.subtext
                                    )
                                }
                                if let seasons = show.numberOfSeasons {
                                    ChipView(icon: "tv", text: "\(seasons) season\(seasons == 1 ? "" : "s")", color: AppTheme.subtext)
                                }
                            }

                            // Overview
                            if !show.overview.isEmpty {
                                Text(show.overview)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.subtext)
                                    .lineSpacing(4)
                            }

                            // Seasons accordion
                            if let seasons = show.seasons?.filter({ $0.seasonNumber > 0 }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("SEASONS")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.subtext)
                                        .tracking(1.5)

                                    ForEach(seasons, id: \.id) { season in
                                        SeasonAccordion(
                                            season: season,
                                            watchedEpisodes: watchedEpisodes,
                                            seasonDetail: seasonDetails[season.seasonNumber],
                                            isExpanded: expandedSeason == season.seasonNumber
                                        ) {
                                            withAnimation(AppTheme.springSnappy()) {
                                                expandedSeason = expandedSeason == season.seasonNumber ? nil : season.seasonNumber
                                            }
                                            if seasonDetails[season.seasonNumber] == nil {
                                                Task { await loadSeason(season.seasonNumber) }
                                            }
                                        } onMarkWatched: { epNum in
                                            Task { await markWatched(season: season.seasonNumber, episode: epNum) }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 60)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else if isLoading {
                ProgressView().tint(AppTheme.accent)
            }
        }
        .navigationBarBackButtonHidden(false)
        .tint(AppTheme.accent)
        .task { await loadShow() }
    }

    private func loadShow() async {
        isLoading = true
        show = try? await TMDBService.shared.fetchShowDetails(id: showId)
        if let uid = authVM.currentUserId {
            watchedEpisodes = (try? await SupabaseManager.shared.fetchWatchedEpisodes(userId: uid, showId: showId)) ?? []
        }
        isLoading = false
    }

    private func loadSeason(_ number: Int) async {
        let detail = try? await TMDBService.shared.fetchSeason(showId: showId, seasonNumber: number)
        if let detail = detail {
            seasonDetails[number] = detail
        }
    }

    private func markWatched(season: Int, episode: Int) async {
        guard let uid = authVM.currentUserId else { return }
        let key = "S\(season)E\(episode)"
        watchedEpisodes.insert(key)
        await showsVM.markEpisodeWatched(userId: uid, showId: showId, season: season, episode: episode)
    }
}

// MARK: - Hero Section

struct HeroSection: View {
    let show: TMDBShow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: show.backdropURL ?? show.posterURL) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                AppTheme.card
            }
            .frame(height: 320)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, AppTheme.background.opacity(0.6), AppTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.text)

                if let year = show.firstAirDate?.prefix(4) {
                    Text(String(year))
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.subtext)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Season Accordion

struct SeasonAccordion: View {
    let season: TMDBSeason
    let watchedEpisodes: Set<String>
    let seasonDetail: TMDBSeasonDetail?
    let isExpanded: Bool
    let onToggle: () -> Void
    let onMarkWatched: (Int) -> Void

    private var watchedCount: Int {
        (1...max(1, season.episodeCount)).filter { watchedEpisodes.contains("S\(season.seasonNumber)E\($0)") }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { HapticManager.light(); onToggle() }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(season.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                        Text("\(watchedCount)/\(season.episodeCount) watched")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.subtext)
                    }

                    Spacer()

                    // Progress
                    CircularProgress(value: Double(watchedCount) / Double(max(1, season.episodeCount)))
                        .frame(width: 32, height: 32)
                        .padding(.trailing, 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.subtext)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(AppTheme.springSnappy(), value: isExpanded)
                }
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Episodes
            if isExpanded {
                VStack(spacing: 0) {
                    if let detail = seasonDetail {
                        ForEach(detail.episodes) { ep in
                            EpisodeRow(
                                episode: ep,
                                isWatched: watchedEpisodes.contains("S\(ep.seasonNumber)E\(ep.episodeNumber)"),
                                onMark: { onMarkWatched(ep.episodeNumber) }
                            )
                        }
                    } else {
                        HStack { Spacer(); ProgressView().tint(AppTheme.accent); Spacer() }
                            .padding()
                    }
                }
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 2)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

struct EpisodeRow: View {
    let episode: TMDBEpisode
    let isWatched: Bool
    let onMark: () -> Void
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Still image
            AsyncImage(url: episode.stillURL) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                AppTheme.card
            }
            .frame(width: 80, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                isWatched ?
                RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.5)) : nil
            )
            .overlay(
                isWatched ?
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                    .font(.system(size: 20)) : nil
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("E\(episode.episodeNumber) · \(episode.name)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isWatched ? AppTheme.subtext : AppTheme.text)
                    .lineLimit(1)

                if let runtime = episode.runtime {
                    Text("\(runtime) min")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.subtext)
                }
            }

            Spacer()

            Button(action: {
                if !isWatched { HapticManager.medium(); onMark() }
            }) {
                Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isWatched ? AppTheme.accent : AppTheme.subtext)
            }
            .buttonStyle(.plain)
            .disabled(isWatched)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        Divider().padding(.leading, 106).background(AppTheme.separator)
    }
}

// MARK: - Chip

struct ChipView: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Circular Progress

struct CircularProgress: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.separator, lineWidth: 3)
            Circle()
                .trim(from: 0, to: value)
                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(AppTheme.springSmooth(), value: value)
        }
    }
}
