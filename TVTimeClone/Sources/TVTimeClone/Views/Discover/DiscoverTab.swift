import SwiftUI

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var trendingShows: [TMDBShow] = []
    @Published var trendingMovies: [TMDBMovie] = []
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var isLoadingTrending = false

    func loadTrending() async {
        isLoadingTrending = true
        async let shows = TMDBService.shared.trendingShows().results
        async let movies = TMDBService.shared.trendingMovies().results
        trendingShows = (try? await shows) ?? []
        trendingMovies = (try? await movies) ?? []
        isLoadingTrending = false
    }

    func search(query: String) async {
        guard !query.isEmpty else { searchResults = []; return }
        isSearching = true
        searchResults = (try? await TMDBService.shared.multiSearch(query: query)) ?? []
        isSearching = false
    }
}

struct DiscoverTab: View {
    @EnvironmentObject private var vm: DiscoverViewModel
    @State private var searchQuery = ""
    @State private var isSearchActive = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Search Bar
                    SearchBar(text: $searchQuery, isActive: $isSearchActive)
                        .padding(.horizontal, 20)
                        .onChange(of: searchQuery) { _, q in
                            Task {
                                try? await Task.sleep(for: .milliseconds(350))
                                if searchQuery == q { await vm.search(query: q) }
                            }
                        }

                    if !searchQuery.isEmpty {
                        // Search results
                        SearchResultsSection(results: vm.searchResults, isSearching: vm.isSearching)
                    } else {
                        // Trending Shows
                        if !vm.trendingShows.isEmpty {
                            DiscoverSection(title: "Trending Shows", icon: "flame.fill") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(vm.trendingShows.prefix(10)) { show in
                                            NavigationLink(destination: ShowDetailView(showId: show.id)) {
                                                DiscoverCard(title: show.name, posterURL: show.posterURL, rating: show.voteAverage)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // Trending Movies
                        if !vm.trendingMovies.isEmpty {
                            DiscoverSection(title: "Trending Movies", icon: "film.stack.fill") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(vm.trendingMovies.prefix(10)) { movie in
                                            NavigationLink(destination: MovieDetailView(movieId: movie.id)) {
                                                DiscoverCard(title: movie.title, posterURL: movie.posterURL, rating: movie.voteAverage)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        if vm.isLoadingTrending {
                            HStack { Spacer(); ProgressView().tint(AppTheme.accent); Spacer() }
                                .padding(.top, 60)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(AppTheme.background)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.loadTrending() }
        .tint(AppTheme.accent)
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isActive: Bool
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.subtext)
                .font(.system(size: 16))

            TextField("Search shows, movies...", text: $text)
                .foregroundStyle(AppTheme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .onChange(of: focused) { _, v in withAnimation(AppTheme.springSnappy()) { isActive = v } }

            if !text.isEmpty {
                Button {
                    text = ""
                    HapticManager.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.subtext)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .animation(AppTheme.springSnappy(), value: text.isEmpty)
    }
}

struct DiscoverSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, icon: icon)
                .padding(.horizontal, 20)
            content()
        }
    }
}

struct DiscoverCard: View {
    let title: String
    let posterURL: URL?
    let rating: Double
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: posterURL) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { AppTheme.card }
            .frame(width: 120, height: 175)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(AppTheme.separator, lineWidth: 0.5)
            )

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            if rating > 0 {
                Text("★ \(String(format: "%.1f", rating))")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow.opacity(0.9))
            }
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onTapGesture { HapticManager.light() }
    }
}

struct SearchResultsSection: View {
    let results: [SearchResult]
    let isSearching: Bool

    var body: some View {
        if isSearching {
            HStack { Spacer(); ProgressView().tint(AppTheme.accent); Spacer() }.padding()
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                    switch result {
                    case .show(let show):
                        NavigationLink(destination: ShowDetailView(showId: show.id)) {
                            SearchResultRow(title: show.name, subtitle: show.firstAirDate?.prefix(4).map(String.init) ?? "",
                                           posterURL: show.posterURL, badge: "TV")
                        }.buttonStyle(.plain)
                    case .movie(let movie):
                        NavigationLink(destination: MovieDetailView(movieId: movie.id)) {
                            SearchResultRow(title: movie.title, subtitle: movie.releaseDate?.prefix(4).map(String.init) ?? "",
                                           posterURL: movie.posterURL, badge: "Film")
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let posterURL: URL?
    let badge: String

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: posterURL) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { AppTheme.card }
            .frame(width: 44, height: 62).clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppTheme.text).lineLimit(1)
                HStack(spacing: 8) {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(AppTheme.subtext)
                    Text(badge).font(.system(size: 10, weight: .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppTheme.accent, in: Capsule())
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(AppTheme.subtext)
        }
        .padding(.vertical, 10)
        Divider().background(AppTheme.separator)
    }
}
