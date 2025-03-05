import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var showingResetAlert = false
    @State private var resetMessage = ""
    @State private var isResetError = false
    
    private func handleLogin() {
        // Validation
        guard !email.isEmpty && !password.isEmpty else {
            authViewModel.errorMessage = "Please fill in all fields"
            return
        }
        
        // Attempt login
        authViewModel.login(email: email, password: password)
    }
    
    private func handleForgotPassword() {
        guard !forgotPasswordEmail.isEmpty else {
            resetMessage = "Please enter your email address"
            isResetError = true
            showingResetAlert = true
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: forgotPasswordEmail) { error in
            if let error = error {
                resetMessage = error.localizedDescription
                isResetError = true
            } else {
                resetMessage = "Password reset email sent. Please check your inbox."
                isResetError = false
                forgotPasswordEmail = ""
            }
            showingResetAlert = true
        }
    }
    
    var body: some View {
        NavigationView {
            if authViewModel.isAuthenticated {
                HomeView(authViewModel: authViewModel)
            } else {
                VStack(spacing: 20) {
                    // Logo
                    Image("deligo_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .padding(.bottom, 80)
                    
                    // Email Input
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.gray)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .disableAutocorrection(true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Password Input
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Login Button
                    Button {
                        handleLogin()
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Login")
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "F4A261"))
                    .cornerRadius(8)
                    .disabled(authViewModel.isLoading)
                    
                    // Forgot Password
                    Button(action: {
                        forgotPasswordEmail = email // Pre-fill with login email
                        showingForgotPassword = true
                    }) {
                        Text("Forgot Password?")
                            .foregroundColor(Color(hex: "1E88E5"))
                    }
                    
                    // Sign Up Link
                    Button(action: {
                        showingSignUp = true
                    }) {
                        Text("Don't have an account? Signup")
                            .foregroundColor(Color(hex: "1E88E5"))
                    }
                }
                .padding(.horizontal, 20)
                .navigationBarHidden(true)
                .sheet(isPresented: $showingSignUp) {
                    SignUpView()
                }
                .alert("Forgot Password", isPresented: $showingForgotPassword) {
                    TextField("Enter your email", text: $forgotPasswordEmail)
                    Button("Cancel", role: .cancel) { }
                    Button("Reset Password") {
                        handleForgotPassword()
                    }
                } message: {
                    Text("Enter your email address and we'll send you instructions to reset your password.")
                }
                .alert(isResetError ? "Error" : "Success", isPresented: $showingResetAlert) {
                    Button("OK") { }
                } message: {
                    Text(resetMessage)
                }
            }
        }
        .alert("Error", isPresented: .constant(authViewModel.errorMessage != nil)) {
            Button("OK") {
                authViewModel.errorMessage = nil
            }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoginView()
}
