import SwiftUI
import FirebaseAuth

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var isError = false
    
    private func resetPassword() {
        guard !email.isEmpty else {
            message = "Please enter your email address"
            isError = true
            return
        }
        
        isLoading = true
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            isLoading = false
            if let error = error {
                message = error.localizedDescription
                isError = true
            } else {
                message = "Password reset email sent. Please check your inbox."
                isError = false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                
                Text("Enter your email address and we'll send you instructions to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
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
                .padding(.horizontal)
                
                Button(action: resetPassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Reset Link")
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("F4A261"))
                .cornerRadius(8)
                .padding(.horizontal)
                .disabled(isLoading)
                
                if let message = message {
                    Text(message)
                        .foregroundColor(isError ? .red : .green)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
} 
