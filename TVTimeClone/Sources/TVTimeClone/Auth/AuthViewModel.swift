import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared

    init() {
        Task { await checkSession() }
    }

    func checkSession() async {
        do {
            let session = try await supabase.currentSession()
            isAuthenticated = session != nil
            currentUserId = session?.user.id.uuidString
        } catch {
            isAuthenticated = false
        }
    }

    // MARK: - Email Auth

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await supabase.signUp(email: email, password: password)
            currentUserId = session.user.id.uuidString
            isAuthenticated = true
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.error()
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await supabase.signIn(email: email, password: password)
            currentUserId = session.user.id.uuidString
            isAuthenticated = true
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.error()
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await supabase.signOut()
            isAuthenticated = false
            currentUserId = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Apple Sign In

    private var currentNonce: String?

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard
                let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = cred.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Apple Sign In failed."
                return
            }
            isLoading = true
            do {
                let session = try await supabase.signInWithApple(idToken: token, nonce: nonce)
                currentUserId = session.user.id.uuidString
                isAuthenticated = true
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                HapticManager.error()
            }
            isLoading = false

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Google Sign In
    // Implement via GoogleSignIn SDK — see TVTIME_SETUP.md

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            randoms.forEach { byte in
                if remainingLength == 0 { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
