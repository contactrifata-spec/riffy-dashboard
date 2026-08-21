import SwiftUI

@MainActor
final class MoviesViewModel: ObservableObject {
    @Published var watchedMovies: [UserMovie] = []
    @Published var isLoading = false
    @Published var error: String?

    func load(userId: String) async {
        isLoading = true
        watchedMovies = (try? await SupabaseManager.shared.fetchUserMovies(userId: userId)) ?? []
        isLoading = false
    }

    func addMovie(_ movie: TMDBMovie, userId: String) async {
        let userMovie = UserMovie(
            id: UUID().uuidString,
            userId: userId,
            movieId: movie.id,
            movieName: movie.title,
            posterPath: movie.posterPath,
            watchedAt: Date()
        )
        try? await SupabaseManager.shared.addUserMovie(userMovie)
        HapticManager.success()
        await load(userId: userId)
    }

    func removeMovie(movieId: Int, userId: String) async {
        try? await SupabaseManager.shared.removeUserMovie(userId: userId, movieId: movieId)
        HapticManager.medium()
        await load(userId: userId)
    }
}

struct MoviesTab: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var vm: MoviesViewModel
    @State private var showAddSheet = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                if vm.watchedMovies.isEmpty && !vm.isLoading {
                    EmptyMoviesState(onAdd: { showAddSheet = true })
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(vm.watchedMovies) { movie in
                            NavigationLink(destination: MovieDetailView(movieId: movie.movieId)) {
                                MovieCell(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Movies")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.medium()
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .refreshable {
                if let uid = authVM.currentUserId { await vm.load(userId: uid) }
            }
            .overlay {
                if vm.isLoading && vm.watchedMovies.isEmpty {
                    ProgressView().tint(AppTheme.accent)
                }
            }
        }
        .task {
            if let uid = authVM.currentUserId { await vm.load(userId: uid) }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMovieSheet().environmentObject(vm).environmentObject(authVM)
        }
        .tint(AppTheme.accent)
    }
}

struct MovieCell: View {
    let movie: UserMovie
    @State private var isPressed = false

    var body: some View {
        AsyncImage(url: movie.posterURL) { img in
            img.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            AppTheme.card
        }
        .aspectRatio(2/3, contentMode: .fill)
        .clipped()
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onTapGesture { HapticManager.light() }
    }
}

struct EmptyMoviesState: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.slash")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.subtext.opacity(0.5))
            Text("No movies yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text)
            Text("Track movies you've watched")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.subtext)
            Button(action: onAdd) {
                Label("Add a Movie", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Add Movie Sheet

struct AddMovieSheet: View {
    @EnvironmentObject private var vm: MoviesViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [TMDBMovie] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.subtext)
                    TextField("Search movies...", text: $query)
                        .foregroundStyle(AppTheme.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                }
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20).padding(.vertical, 16)

                if isSearching { ProgressView().tint(AppTheme.accent).padding() }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { movie in
                            Button { Task { await add(movie) } } label: {
                                MovieSearchRow(movie: movie)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(AppTheme.accent)
                }
            }
        }
        .onChange(of: query) { _, new in
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                if query == new && !new.isEmpty { await search() }
            }
        }
    }

    private func search() async {
        guard !query.isEmpty else { results = []; return }
        isSearching = true
        results = (try? await TMDBService.shared.searchMovies(query: query).results) ?? []
        isSearching = false
    }

    private func add(_ movie: TMDBMovie) async {
        guard let uid = authVM.currentUserId else { return }
        await vm.addMovie(movie, userId: uid)
        dismiss()
    }
}

struct MovieSearchRow: View {
    let movie: TMDBMovie
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: movie.posterURL) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { AppTheme.card }
            .frame(width: 46, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.text).lineLimit(1)
                HStack(spacing: 8) {
                    if let year = movie.releaseDate?.prefix(4) {
                        Text(year).font(.system(size: 13)).foregroundStyle(AppTheme.subtext)
                    }
                    if movie.voteAverage > 0 {
                        Text("★ \(String(format: "%.1f", movie.voteAverage))")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                    }
                }
                Text(movie.overview).font(.system(size: 12)).foregroundStyle(AppTheme.subtext).lineLimit(2)
            }
            Spacer()
            Image(systemName: "plus.circle").font(.system(size: 20)).foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 20).padding(.vertical, 12).background(AppTheme.background)
        Divider().padding(.leading, 80).background(AppTheme.separator)
    }
}

// MARK: - Movie Detail

struct MovieDetailView: View {
    let movieId: Int
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var vm: MoviesViewModel
    @State private var movie: TMDBMovie?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if let movie = movie {
                ScrollView {
                    VStack(spacing: 0) {
                        // Backdrop
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: movie.backdropURL ?? movie.posterURL) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { AppTheme.card }
                            .frame(height: 280).clipped()
                            .overlay(LinearGradient(colors: [.clear, AppTheme.background], startPoint: .center, endPoint: .bottom))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(movie.title)
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundStyle(AppTheme.text)
                                if let year = movie.releaseDate?.prefix(4) {
                                    Text(String(year)).font(.system(size: 14)).foregroundStyle(AppTheme.subtext)
                                }
                            }.padding(20)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 10) {
                                if movie.voteAverage > 0 {
                                    ChipView(icon: "star.fill", text: String(format: "%.1f", movie.voteAverage), color: .yellow)
                                }
                                if let runtime = movie.runtime {
                                    ChipView(icon: "clock", text: "\(runtime) min", color: AppTheme.subtext)
                                }
                            }
                            Text(movie.overview)
                                .font(.system(size: 14)).foregroundStyle(AppTheme.subtext).lineSpacing(4)
                        }
                        .padding(20)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else if isLoading {
                ProgressView().tint(AppTheme.accent)
            }
        }
        .tint(AppTheme.accent)
        .task { movie = try? await TMDBService.shared.fetchMovie(id: movieId); isLoading = false }
    }
}
