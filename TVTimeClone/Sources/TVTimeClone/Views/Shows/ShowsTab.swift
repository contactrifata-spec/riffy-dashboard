import SwiftUI

struct ShowsTab: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var vm: ShowsViewModel
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    // Keep Watching
                    if !vm.keepWatchingShows.isEmpty {
                        KeepWatchingSection(shows: vm.keepWatchingShows)
                    }

                    // Up to Date
                    if !vm.upToDateShows.isEmpty {
                        UpToDateSection(shows: vm.upToDateShows)
                    }

                    // Empty state
                    if vm.keepWatchingShows.isEmpty && vm.upToDateShows.isEmpty && !vm.isLoading {
                        EmptyShowsState(onAdd: { showAddSheet = true })
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(AppTheme.background)
            .navigationTitle("Shows")
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
                if let uid = authVM.currentUserId {
                    await vm.load(userId: uid)
                }
            }
            .overlay {
                if vm.isLoading && vm.keepWatchingShows.isEmpty {
                    ProgressView()
                        .tint(AppTheme.accent)
                }
            }
        }
        .task {
            if let uid = authVM.currentUserId {
                await vm.load(userId: uid)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddShowSheet()
                .environmentObject(vm)
                .environmentObject(authVM)
        }
        .tint(AppTheme.accent)
    }
}

// MARK: - Keep Watching Section

struct KeepWatchingSection: View {
    let shows: [UserShowWithDetails]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Keep Watching", icon: "play.fill")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(shows) { show in
                        NavigationLink(destination: ShowDetailView(showId: show.userShow.showId)) {
                            KeepWatchingCard(show: show)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct KeepWatchingCard: View {
    let show: UserShowWithDetails
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: show.userShow.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    AppTheme.card
                }
                .frame(width: 140, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))

                // Next episode badge
                if let next = show.nextUnwatchedEpisode {
                    Text("S\(next.season)E\(next.episode)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                }
            }

            // Show name
            Text(show.tmdbShow.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            // Next episode label
            Text(show.nextEpisodeDisplay)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.subtext)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onTapGesture { HapticManager.light() }
    }
}

// MARK: - Up to Date Section

struct UpToDateSection: View {
    let shows: [UserShowWithDetails]
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Up to Date", icon: "checkmark.circle.fill")
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(shows) { show in
                    NavigationLink(destination: ShowDetailView(showId: show.userShow.showId)) {
                        UpToDateCell(show: show)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct UpToDateCell: View {
    let show: UserShowWithDetails
    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: show.userShow.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                AppTheme.card
            }
            .aspectRatio(2/3, contentMode: .fill)
            .clipped()

            // Accent border bottom indicator
            Rectangle()
                .fill(AppTheme.accent)
                .frame(height: 3)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(Rectangle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onTapGesture { HapticManager.light() }
    }
}

// MARK: - Supporting views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.subtext)
                .tracking(1.5)
        }
    }
}

struct EmptyShowsState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.slash")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.subtext.opacity(0.5))

            Text("No shows yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text)

            Text("Start tracking your favorite shows")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.subtext)

            Button(action: onAdd) {
                Label("Add a Show", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }
}

// MARK: - Add Show Sheet

struct AddShowSheet: View {
    @EnvironmentObject private var vm: ShowsViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [TMDBShow] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.subtext)
                    TextField("Search shows...", text: $query)
                        .foregroundStyle(AppTheme.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                }
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if isSearching {
                    ProgressView().tint(AppTheme.accent).padding()
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { show in
                            Button {
                                Task { await addShow(show) }
                            } label: {
                                ShowSearchRow(show: show)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Add Show")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
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
        results = (try? await TMDBService.shared.searchShows(query: query).results) ?? []
        isSearching = false
    }

    private func addShow(_ show: TMDBShow) async {
        guard let uid = authVM.currentUserId else { return }
        let userShow = UserShow(
            id: UUID().uuidString,
            userId: uid,
            showId: show.id,
            showName: show.name,
            posterPath: show.posterPath,
            status: .watching,
            currentSeason: 1,
            currentEpisode: 0,
            totalWatchedEpisodes: 0,
            lastWatchedAt: nil
        )
        try? await SupabaseManager.shared.upsertUserShow(userShow)
        HapticManager.success()
        await vm.load(userId: uid)
        dismiss()
    }
}

struct ShowSearchRow: View {
    let show: TMDBShow

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: show.posterURL) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                AppTheme.card
            }
            .frame(width: 46, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let year = show.firstAirDate?.prefix(4) {
                        Text(year)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.subtext)
                    }
                    if let status = show.status {
                        Text("·")
                            .foregroundStyle(AppTheme.subtext)
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundStyle(show.isReturning ? AppTheme.accent : AppTheme.subtext)
                    }
                }

                if !show.overview.isEmpty {
                    Text(show.overview)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.subtext)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "plus.circle")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.background)
        Divider().padding(.leading, 80).background(AppTheme.separator)
    }
}
