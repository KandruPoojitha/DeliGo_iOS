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
        .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                email = ""
                password = ""
            }
        }
    }
}

#Preview {
    LoginView()
}
