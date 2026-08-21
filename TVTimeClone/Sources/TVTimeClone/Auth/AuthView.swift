import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct AuthView: View {
    @State private var showingLogin = true

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // Ambient glow background
            GeometryReader { geo in
                Circle()
                    .fill(AppTheme.accentDim.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.1)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("Riffy")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.text)

                    Text("Track what you watch")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(AppTheme.subtext)
                }
                .padding(.top, 80)
                .padding(.bottom, 48)

                // Toggle
                HStack(spacing: 0) {
                    ForEach(["Sign In", "Sign Up"], id: \.self) { tab in
                        let isSelected = (tab == "Sign In") == showingLogin
                        Button {
                            HapticManager.selection()
                            withAnimation(AppTheme.springSnappy()) {
                                showingLogin = tab == "Sign In"
                            }
                        } label: {
                            Text(tab)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isSelected ? .black : AppTheme.subtext)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    isSelected ? AppTheme.accent : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // Form
                Group {
                    if showingLogin {
                        LoginForm()
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        SignUpForm()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(AppTheme.springSnappy(), value: showingLogin)

                Spacer()
            }
        }
    }
}

// MARK: - Login Form

struct LoginForm: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var hashedNonce = ""

    var body: some View {
        VStack(spacing: 16) {
            AuthTextField(placeholder: "Email", text: $email, icon: "envelope")
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)

            AuthTextField(placeholder: "Password", text: $password, icon: "lock", isSecure: !showPassword) {
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(AppTheme.subtext)
                }
            }
            .textContentType(.password)

            PrimaryButton(title: "Sign In", isLoading: authVM.isLoading) {
                Task { await authVM.signIn(email: email, password: password) }
            }

            DividerLabel(text: "or")

            SignInWithAppleButton { request in
                hashedNonce = authVM.prepareAppleSignIn()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                Task { await authVM.handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

            GoogleSignInButton()

            if let err = authVM.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 24)
        .animation(AppTheme.springSmooth(), value: authVM.errorMessage)
    }
}

// MARK: - Sign Up Form

struct SignUpForm: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var hashedNonce = ""

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        VStack(spacing: 16) {
            AuthTextField(placeholder: "Email", text: $email, icon: "envelope")
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)

            AuthTextField(placeholder: "Password", text: $password, icon: "lock", isSecure: !showPassword)
                .textContentType(.newPassword)

            AuthTextField(placeholder: "Confirm Password", text: $confirmPassword, icon: "lock.shield",
                          isSecure: !showPassword, isError: passwordMismatch)
                .textContentType(.newPassword)

            if passwordMismatch {
                Text("Passwords don't match")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }

            PrimaryButton(title: "Create Account",
                          isLoading: authVM.isLoading,
                          isDisabled: passwordMismatch || email.isEmpty || password.isEmpty) {
                Task { await authVM.signUp(email: email, password: password) }
            }

            DividerLabel(text: "or")

            SignInWithAppleButton { request in
                hashedNonce = authVM.prepareAppleSignIn()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                Task { await authVM.handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

            GoogleSignInButton()

            if let err = authVM.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .animation(AppTheme.springSmooth(), value: passwordMismatch)
        .animation(AppTheme.springSmooth(), value: authVM.errorMessage)
    }
}

// MARK: - Shared Components

struct AuthTextField<Accessory: View>: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false
    var isError: Bool = false
    @ViewBuilder var accessory: () -> Accessory

    init(placeholder: String, text: Binding<String>, icon: String,
         isSecure: Bool = false, isError: Bool = false,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.isError = isError
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.subtext)
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 16))
            .foregroundStyle(AppTheme.text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            accessory()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(AppTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(isError ? Color.red.opacity(0.6) : AppTheme.separator, lineWidth: 1)
                )
        )
    }
}

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.85)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isDisabled ? AppTheme.accentDim : AppTheme.accent)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading || isDisabled)
    }
}

// MARK: - Google Sign-In Button

struct GoogleSignInButton: View {
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        Button {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }
            Task { await authVM.signInWithGoogle(presenting: root) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .medium))
                Text("Sign in with Google")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct DividerLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(AppTheme.separator).frame(height: 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.subtext)
            Rectangle().fill(AppTheme.separator).frame(height: 1)
        }
    }
}
