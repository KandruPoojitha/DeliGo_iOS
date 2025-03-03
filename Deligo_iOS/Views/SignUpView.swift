import SwiftUI

enum UserRole: String, CaseIterable {
    case customer = "Customer"
    case restaurant = "Restaurant"
    case driver = "Driver"
    case admin = "Admin"
}

struct SignUpView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Form Fields
    @State private var selectedRole = UserRole.customer
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var phoneNumber: String = ""
    @State private var showPasswordMismatchAlert = false
    
    private func handleSignUp() {
        // Validate passwords match
        guard password == confirmPassword else {
            showPasswordMismatchAlert = true
            return
        }
        
        // Call signup method
        authViewModel.signUp(
            name: name,
            email: email,
            password: password,
            phoneNumber: phoneNumber,
            role: selectedRole
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Logo
                Image("deligo_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .padding(.bottom, 20)
                
                // Role Selector
                Picker("Select Role", selection: $selectedRole) {
                    ForEach(UserRole.allCases.filter { $0 != .admin }, id: \.self) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Form Fields
                Group {
                    // Name Input
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.gray)
                        TextField("Full Name", text: $name)
                            .textContentType(.name)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
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
                    
                    // Password Input
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Confirm Password Input
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Phone Input
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(.gray)
                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Sign Up Button
                Button(action: handleSignUp) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign Up")
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "F4A261"))
                .cornerRadius(8)
                .disabled(authViewModel.isLoading)
                
                // Login Link
                Button(action: {
                    dismiss()
                }) {
                    Text("Already have an account? Login")
                        .foregroundColor(Color(hex: "1E88E5"))
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(authViewModel.errorMessage != nil)) {
            Button("OK") {
                authViewModel.errorMessage = nil
            }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
        .alert("Password Mismatch", isPresented: $showPasswordMismatchAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Passwords do not match")
        }
        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
} 