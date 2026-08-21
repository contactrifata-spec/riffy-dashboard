import SwiftUI
import Supabase

@main
struct TVTimeCloneApp: App {
    @StateObject private var authVM = AuthViewModel()

    init() {
        SupabaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isAuthenticated {
                    ContentView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.02)),
                            removal: .opacity
                        ))
                } else {
                    AuthView()
                        .transition(.opacity)
                }
            }
            .environmentObject(authVM)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: authVM.isAuthenticated)
            .preferredColorScheme(.dark)
        }
    }
}
