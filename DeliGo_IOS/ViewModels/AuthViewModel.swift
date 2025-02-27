import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var currentUserRole: UserRole?
    @Published var showSuccessMessage = false
    
    private let auth = Auth.auth()
    private let db = Database.database().reference()
    
    init() {
        // Check if user is already signed in
        checkAuthStatus()
    }
    
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
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
                    // Fetch user role from Realtime Database
                    self.fetchUserRole(userId: userId)
                }
            }
        }
    }
    
    private func fetchUserRole(userId: String) {
        // Check in each role collection
        for role in UserRole.allCases {
            let rolePath = "\(role.rawValue.lowercased())s/\(userId)"
            db.child(rolePath).observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let self = self else { return }
                
                if snapshot.exists() {
                    DispatchQueue.main.async {
                        self.currentUserRole = role
                        self.isAuthenticated = true
                        
                        // Save user data to UserDefaults for persistence
                        UserDefaults.standard.set(role.rawValue, forKey: "userRole")
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    }
                }
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
        // Create user data dictionary
        let userData: [String: Any] = [
            "fullName": fullName,
            "email": email,
            "phone": phone,
            "role": role.rawValue,
            "createdAt": ServerValue.timestamp()
        ]
        
        // Save user data in the appropriate collection based on role
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
                self.isAuthenticated = true
                
                // Save user data to UserDefaults for persistence
                UserDefaults.standard.set(role.rawValue, forKey: "userRole")
                UserDefaults.standard.set(true, forKey: "isAuthenticated")
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
            
            // Clear saved user data
            UserDefaults.standard.removeObject(forKey: "userRole")
            UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // Check if user is already signed in when app launches
    func checkAuthStatus() {
        if let user = auth.currentUser {
            // Check if we have saved role
            if let savedRole = UserDefaults.standard.string(forKey: "userRole"),
               let role = UserRole(rawValue: savedRole),
               UserDefaults.standard.bool(forKey: "isAuthenticated") {
                self.currentUserRole = role
                self.isAuthenticated = true
            } else {
                // If no saved role, fetch from Firebase
                fetchUserRole(userId: user.uid)
            }
        }
    }
} 