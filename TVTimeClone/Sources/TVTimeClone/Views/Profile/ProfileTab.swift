import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var finishedShows: [UserShow] = []
    @Published var userLists: [UserList] = []
    @Published var isLoading = false

    func load(userId: String) async {
        isLoading = true
        async let prof = SupabaseManager.shared.fetchProfile(userId: userId)
        async let shows = SupabaseManager.shared.fetchUserShows(userId: userId)
        async let lists = SupabaseManager.shared.fetchUserLists(userId: userId)

        profile = try? await prof
        let allShows = (try? await shows) ?? []
        finishedShows = allShows.filter { $0.status == .finished || $0.status == .dropped }
        userLists = (try? await lists) ?? []
        isLoading = false
    }
}

struct ProfileTab: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var showsVM: ShowsViewModel
    @EnvironmentObject private var moviesVM: MoviesViewModel
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    ProfileHeader(
                        profile: profileVM.profile,
                        showsWatched: showsVM.keepWatchingShows.count + showsVM.upToDateShows.count + profileVM.finishedShows.count,
                        moviesWatched: moviesVM.watchedMovies.count,
                        onFollowersTab: { showFollowers = true },
                        onFollowingTab: { showFollowing = true },
                        onEditProfile: { showEditProfile = true }
                    )

                    Divider().background(AppTheme.separator).padding(.vertical, 8)

                    // Finished / Watched Shows
                    if !profileVM.finishedShows.isEmpty {
                        WatchedShowsSection(shows: profileVM.finishedShows)
                    }

                    // Watched Movies
                    if !moviesVM.watchedMovies.isEmpty {
                        WatchedMoviesSection(movies: moviesVM.watchedMovies)
                    }

                    // Custom Lists
                    CustomListsSection(
                        lists: profileVM.userLists,
                        userId: authVM.currentUserId ?? "",
                        onRefresh: { if let uid = authVM.currentUserId { await profileVM.load(userId: uid) } }
                    )

                    // Sign Out
                    Button {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                if let uid = authVM.currentUserId { await profileVM.load(userId: uid) }
            }
        }
        .task {
            if let uid = authVM.currentUserId {
                await profileVM.load(userId: uid)
                await moviesVM.load(userId: uid)
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await authVM.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showFollowers) {
            FollowListSheet(title: "Followers")
        }
        .sheet(isPresented: $showFollowing) {
            FollowListSheet(title: "Following")
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(profile: profileVM.profile)
                .environmentObject(profileVM)
                .environmentObject(authVM)
        }
        .tint(AppTheme.accent)
    }
}

// MARK: - Profile Header

struct ProfileHeader: View {
    let profile: UserProfile?
    let showsWatched: Int
    let moviesWatched: Int
    let onFollowersTab: () -> Void
    let onFollowingTab: () -> Void
    let onEditProfile: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Avatar + Edit
            HStack {
                Spacer()
                Button(action: { HapticManager.light(); onEditProfile() }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.accent)
                        .padding(10)
                        .background(AppTheme.card, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Avatar
            ZStack {
                if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        AvatarPlaceholder()
                    }
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(AppTheme.accent, lineWidth: 2))
                } else {
                    AvatarPlaceholder()
                }
            }

            // Name + username
            VStack(spacing: 4) {
                Text(profile?.displayName ?? "Your Name")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)

                if let username = profile?.username {
                    Text("@\(username)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.subtext)
                }

                if let bio = profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.subtext)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 30)
                        .padding(.top, 2)
                }
            }

            // Stats row — all 4 are tappable
            HStack(spacing: 0) {
                StatButton(count: showsWatched, label: "Shows", action: nil)
                Divider().frame(height: 30).background(AppTheme.separator)
                StatButton(count: moviesWatched, label: "Movies", action: nil)
                Divider().frame(height: 30).background(AppTheme.separator)
                StatButton(count: profile?.followersCount ?? 0, label: "Followers", action: {
                    HapticManager.light()
                    onFollowersTab()
                })
                Divider().frame(height: 30).background(AppTheme.separator)
                StatButton(count: profile?.followingCount ?? 0, label: "Following", action: {
                    HapticManager.light()
                    onFollowingTab()
                })
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }
}

struct StatButton: View {
    let count: Int
    let label: String
    let action: (() -> Void)?
    @State private var isPressed = false

    var body: some View {
        let content = VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity)

        if let action = action {
            Button(action: action) {
                content
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        } else {
            content
        }
    }
}

struct AvatarPlaceholder: View {
    var body: some View {
        ZStack {
            Circle().fill(AppTheme.card)
                .frame(width: 90, height: 90)
                .overlay(Circle().strokeBorder(AppTheme.separator, lineWidth: 1.5))
            Image(systemName: "person.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.subtext)
        }
    }
}

// MARK: - Watched Shows Section

struct WatchedShowsSection: View {
    let shows: [UserShow]
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Watched Shows", icon: "checkmark.seal.fill")
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(shows) { show in
                    NavigationLink(destination: ShowDetailView(showId: show.showId)) {
                        ProfilePosterCard(posterURL: show.posterURL, title: show.showName, badge: show.status == .dropped ? "Dropped" : nil)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Watched Movies Section

struct WatchedMoviesSection: View {
    let movies: [UserMovie]
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Watched Movies", icon: "film.fill")
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(movies) { movie in
                    NavigationLink(destination: MovieDetailView(movieId: movie.movieId)) {
                        ProfilePosterCard(posterURL: movie.posterURL, title: movie.movieName)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 20)
    }
}

// Larger poster card for profile (bigger than the 2px-gap grid in main tabs)
struct ProfilePosterCard: View {
    let posterURL: URL?
    let title: String
    var badge: String? = nil
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: posterURL) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { AppTheme.card }
                .frame(height: 155)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(AppTheme.separator, lineWidth: 0.5)
                )

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.red.opacity(0.85), in: Capsule())
                        .padding(6)
                }
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.subtext)
                .lineLimit(1)
        }
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

// MARK: - Custom Lists

struct CustomListsSection: View {
    let lists: [UserList]
    let userId: String
    let onRefresh: () async -> Void
    @State private var showCreateList = false
    @State private var newListName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Custom Lists", icon: "list.bullet")
                Spacer()
                Button {
                    HapticManager.light()
                    showCreateList = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 20)

            if lists.isEmpty {
                Button {
                    HapticManager.light()
                    showCreateList = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create a new list")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(AppTheme.separator, style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(lists) { list in
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 24)
                            Text(list.name)
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.subtext)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 16)
        .alert("New List", isPresented: $showCreateList) {
            TextField("List name", text: $newListName)
            Button("Cancel", role: .cancel) { newListName = "" }
            Button("Create") {
                guard !newListName.isEmpty else { return }
                let name = newListName
                newListName = ""
                Task {
                    try? await SupabaseManager.shared.createList(userId: userId, name: name)
                    await onRefresh()
                }
            }
        }
    }
}

// MARK: - Follow list sheet (placeholder)

struct FollowListSheet: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "person.2")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.subtext.opacity(0.5))
                Text("No \(title.lowercased()) yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .padding(.top, 12)
                Spacer()
            }
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(AppTheme.accent)
                }
            }
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    let profile: UserProfile?
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Your Name", text: $displayName)
                        .foregroundStyle(AppTheme.text)
                }
                Section("Username") {
                    HStack {
                        Text("@").foregroundStyle(AppTheme.subtext)
                        TextField("username", text: $username)
                            .foregroundStyle(AppTheme.text)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
                Section("Bio") {
                    TextEditor(text: $bio)
                        .foregroundStyle(AppTheme.text)
                        .frame(height: 80)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(AppTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .disabled(isSaving)
                }
            }
        }
        .onAppear {
            displayName = profile?.displayName ?? ""
            username = profile?.username ?? ""
            bio = profile?.bio ?? ""
        }
    }

    private func save() async {
        guard let uid = authVM.currentUserId else { return }
        isSaving = true
        var updated = profile ?? UserProfile(
            id: uid, username: nil, displayName: nil, avatarUrl: nil, bio: nil,
            followersCount: 0, followingCount: 0
        )
        let mutableProfile = UserProfile(
            id: uid,
            username: username.isEmpty ? nil : username,
            displayName: displayName.isEmpty ? nil : displayName,
            avatarUrl: updated.avatarUrl,
            bio: bio.isEmpty ? nil : bio,
            followersCount: updated.followersCount,
            followingCount: updated.followingCount
        )
        try? await SupabaseManager.shared.updateProfile(mutableProfile)
        HapticManager.success()
        await profileVM.load(userId: uid)
        isSaving = false
        dismiss()
    }
}
