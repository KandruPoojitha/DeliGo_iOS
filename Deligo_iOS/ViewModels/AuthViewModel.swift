import SwiftUI
import FirebaseAuth
import FirebaseDatabase

enum DocumentStatus {
    case notSubmitted
    case pending
    case approved
    case rejected
}

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var currentUserRole: UserRole?
    @Published var documentStatus: DocumentStatus = .notSubmitted
    @Published var showSuccessMessage = false
    
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private let auth = Auth.auth()
    private let db = Database.database().reference()
    
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        print("Starting login process for email: \(email)")
        
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            print("Login attempt completed")
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Login error: \(error.localizedDescription)")
                    // Handle specific error cases
                    switch error {
                    case AuthErrorCode.wrongPassword:
                        self.errorMessage = "Invalid email or password"
                    case AuthErrorCode.invalidEmail:
                        self.errorMessage = "Please enter a valid email address"
                    case AuthErrorCode.userNotFound:
                        self.errorMessage = "No account found with this email"
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                if let userId = result?.user.uid {
                    print("Login successful for user: \(userId)")
                    // Check if user is admin first
                    self.checkAdminRole(userId: userId)
                }
            }
        }
    }
    
    private func checkAdminRole(userId: String) {
        db.child("admins/\(userId)").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if snapshot.exists() {
                print("Found admin user")
                DispatchQueue.main.async {
                    self.currentUserRole = .admin
                    self.isAuthenticated = true
                }
            } else {
                // If not admin, check other roles
                self.checkOtherRoles(userId: userId)
            }
        }
    }
    
    private func checkOtherRoles(userId: String) {
        for role in UserRole.allCases where role != .admin {
            let rolePath = "\(role.rawValue.lowercased())s/\(userId)"
            db.child(rolePath).observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let self = self else { return }
                
                if snapshot.exists() {
                    print("Found user role: \(role.rawValue)")
                    
                    if role == .restaurant {
                        self.checkDocumentStatus(userId: userId)
                    } else {
                        DispatchQueue.main.async {
                            self.currentUserRole = role
                            self.isAuthenticated = true
                        }
                    }
                }
            }
        }
    }
    
    private func checkDocumentStatus(userId: String) {
        db.child("restaurants/\(userId)/documents").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let documentsData = snapshot.value as? [String: Any],
                   let status = documentsData["status"] as? String {
                    switch status {
                    case "pending":
                        self.documentStatus = .pending
                    case "approved":
                        self.documentStatus = .approved
                    case "rejected":
                        self.documentStatus = .rejected
                    default:
                        self.documentStatus = .notSubmitted
                    }
                } else {
                    self.documentStatus = .notSubmitted
                }
                
                self.currentUserRole = .restaurant
                self.isAuthenticated = true
            }
        }
    }
    
    func signUp(
        name: String,
        email: String,
        password: String,
        phoneNumber: String,
        role: UserRole
    ) {
        isLoading = true
        errorMessage = nil
        
        // Validation
        guard !name.isEmpty && !email.isEmpty && !password.isEmpty && !phoneNumber.isEmpty else {
            errorMessage = "Please fill in all fields"
            isLoading = false
            return
        }
        
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.isLoading = false
                    // Handle specific signup errors
                    switch error {
                    case AuthErrorCode.emailAlreadyInUse:
                        self.errorMessage = "This email is already registered"
                    case AuthErrorCode.invalidEmail:
                        self.errorMessage = "Please enter a valid email address"
                    case AuthErrorCode.weakPassword:
                        self.errorMessage = "Password should be at least 6 characters"
                    default:
                        self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                    }
                    return
                }
                
                if let userId = result?.user.uid {
                    // Save user data
                    self.saveUserData(
                        userId: userId,
                        role: role,
                        fullName: name,
                        email: email,
                        phone: phoneNumber
                    )
                }
            }
        }
    }
    
    private func saveUserData(userId: String, role: UserRole, fullName: String, email: String, phone: String) {
        
        let userData: [String: Any] = [
            "fullName": fullName,
            "email": email,
            "phone": phone,
            "role": role.rawValue,
            "createdAt": ServerValue.timestamp()
        ]
        
        db.child("\(role.rawValue.lowercased())s").child(userId).setValue(userData) { [weak self] error, _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Failed to save user data: \(error.localizedDescription)"
                    return
                }
                
                self.showSuccessMessage = true
                self.currentUserRole = role
                if role == .restaurant {
                    self.documentStatus = .notSubmitted
                }
                self.isAuthenticated = true
            }
        }
    }
    
    func forgotPassword(email: String) {
        isLoading = true
        errorMessage = nil
        
        auth.sendPasswordReset(withEmail: email) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    switch error {
                    case AuthErrorCode.invalidEmail:
                        self.errorMessage = "Please enter a valid email address"
                    case AuthErrorCode.userNotFound:
                        self.errorMessage = "No account found with this email"
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                self.errorMessage = "Password reset link sent to your email"
            }
        }
    }
    
    func logout() {
        do {
            try auth.signOut()
            isAuthenticated = false
            currentUserRole = nil
            documentStatus = .notSubmitted
        } catch {
            errorMessage = error.localizedDescription
        }
    }
} 
