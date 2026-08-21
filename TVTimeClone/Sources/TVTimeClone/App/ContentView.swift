import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .shows
    @StateObject private var showsVM = ShowsViewModel()
    @StateObject private var moviesVM = MoviesViewModel()
    @StateObject private var discoverVM = DiscoverViewModel()
    @StateObject private var profileVM = ProfileViewModel()

    enum Tab { case shows, movies, discover, profile }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ShowsTab()
                    .environmentObject(showsVM)
                    .tag(Tab.shows)

                MoviesTab()
                    .environmentObject(moviesVM)
                    .tag(Tab.movies)

                DiscoverTab()
                    .environmentObject(discoverVM)
                    .tag(Tab.discover)

                ProfileTab()
                    .environmentObject(profileVM)
                    .environmentObject(showsVM)
                    .environmentObject(moviesVM)
                    .tag(Tab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.38, dampingFraction: 0.88), value: selectedTab)

            CustomTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .background(AppTheme.background)
    }
}

struct CustomTabBar: View {
    @Binding var selected: ContentView.Tab
    private let items: [(tab: ContentView.Tab, icon: String, label: String)] = [
        (.shows, "tv", "Shows"),
        (.movies, "film", "Movies"),
        (.discover, "safari", "Discover"),
        (.profile, "person.circle", "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                TabBarButton(
                    icon: item.icon,
                    label: item.label,
                    isSelected: selected == item.tab
                ) {
                    HapticManager.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selected = item.tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            AppTheme.surface
                .overlay(
                    Divider().frame(height: 0.5).background(Color.white.opacity(0.08)),
                    alignment: .top
                )
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.subtext)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.subtext)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
