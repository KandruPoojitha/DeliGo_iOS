import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authViewModel = AuthViewModel()
    @State private var email: String = ""
    
    private func isEmailValid() -> Bool {
        guard !email.isEmpty else {
            authViewModel.errorMessage = "Please enter your email address"
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            authViewModel.errorMessage = "Please enter a valid email address"
            return false
        }
        
        return true
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo
            Image("deligo_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.top, 40)
            
            Text("Reset Password")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enter your email address and we'll send you a link to reset your password")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            // Email Input
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.gray)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.top, 20)
            
            // Send Reset Link Button
            Button(action: {
                if isEmailValid() {
                    authViewModel.forgotPassword(email: email)
                }
            }) {
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Send Reset Link")
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "F4A261"))
            .cornerRadius(8)
            .disabled(authViewModel.isLoading)
            
            // Back to Login Button
            Button(action: {
                dismiss()
            }) {
                Text("Back to Login")
                    .foregroundColor(Color(hex: "1E88E5"))
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Message", isPresented: .constant(authViewModel.errorMessage != nil)) {
            Button("OK") {
                if authViewModel.errorMessage == "Password reset link sent to your email" {
                    dismiss()
                }
                authViewModel.errorMessage = nil
            }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
} 