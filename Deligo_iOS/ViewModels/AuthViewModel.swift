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
    
    // User data properties
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var email: String? {
        Auth.auth().currentUser?.email
    }
    
    var phone: String? {
        return phoneNumber
    }
    
    @Published var fullName: String?
    @Published var phoneNumber: String?
    
    private let auth = Auth.auth()
    private let db = Database.database().reference()
    
    func login(email: String, password: String) {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        print("Starting login process for email: \(email)")
        
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("Login error: \(error.localizedDescription)")
                    
                    switch error {
                    case AuthErrorCode.wrongPassword:
                        self.errorMessage = "Invalid email or password"
                    case AuthErrorCode.invalidEmail:
                        self.errorMessage = "Please enter a valid email address"
                    case AuthErrorCode.userNotFound:
                        self.errorMessage = "No account found with this email"
                    default:
                        self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                    }
                }
                return
            }
            
            if let userId = result?.user.uid {
                print("Login successful for user: \(userId)")
                self.checkUserRoleAndRedirect(userId: userId)
            }
        }
    }
    
    private func checkUserRoleAndRedirect(userId: String) {
        // First check if user is admin
        db.child("admins").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if snapshot.exists() {
                print("Found admin user")
                if let userData = snapshot.value as? [String: Any] {
                    self.updateUserData(from: userData)
                }
                DispatchQueue.main.async {
                    self.currentUserRole = .admin
                    self.isAuthenticated = true
                    self.isLoading = false
                }
                return
            }
            self.checkInCustomers(userId: userId)
        } withCancel: { [weak self] error in
            self?.handleDatabaseError(error)
        }
    }
    
    private func checkInCustomers(userId: String) {
        db.child("customers").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if snapshot.exists() {
                print("Found customer user")
                if let userData = snapshot.value as? [String: Any] {
                    self.updateUserData(from: userData)
                    
                    // Check if the customer is blocked
                    if let isBlocked = userData["blocked"] as? Bool, isBlocked {
                        print("User is blocked and cannot log in: \(userId)")
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = "Your account has been blocked. Please contact support for assistance."
                            // Log the user out since they're blocked
                            self.logout()
                        }
                        return
                    }
                }
                DispatchQueue.main.async {
                    self.currentUserRole = .customer
                    self.isAuthenticated = true
                    self.isLoading = false
                }
                return
            }
            self.checkInDrivers(userId: userId)
        } withCancel: { [weak self] error in
            self?.handleDatabaseError(error)
        }
    }
    
    private func checkInDrivers(userId: String) {
        db.child("drivers").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if snapshot.exists() {
                print("Found driver user")
                if let userData = snapshot.value as? [String: Any] {
                    self.updateUserData(from: userData)
                    
                    // Check if the driver is blocked
                    if let isBlocked = userData["blocked"] as? Bool, isBlocked {
                        print("Driver is blocked and cannot log in: \(userId)")
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = "Your account has been blocked. Please contact support for assistance."
                            // Log the user out since they're blocked
                            self.logout()
                        }
                        return
                    }
                }
                DispatchQueue.main.async {
                    self.currentUserRole = .driver
                    self.isAuthenticated = true
                    self.isLoading = false
                }
                return
            }
            self.checkInRestaurants(userId: userId)
        } withCancel: { [weak self] error in
            self?.handleDatabaseError(error)
        }
    }
    
    private func checkInRestaurants(userId: String) {
        db.child("restaurants").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if snapshot.exists() {
                print("Found restaurant user")
                if let userData = snapshot.value as? [String: Any] {
                    self.updateUserData(from: userData)
                    
                    // Check if the restaurant is blocked
                    if let isBlocked = userData["blocked"] as? Bool, isBlocked {
                        print("Restaurant is blocked and cannot log in: \(userId)")
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = "Your account has been blocked. Please contact support for assistance."
                            // Log the user out since they're blocked
                            self.logout()
                        }
                        return
                    }
                }
                if let documentsData = snapshot.childSnapshot(forPath: "documents").value as? [String: Any],
                   let status = documentsData["status"] as? String {
                    DispatchQueue.main.async {
                        self.currentUserRole = .restaurant
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
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.currentUserRole = .restaurant
                        self.documentStatus = .notSubmitted
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                }
                return
            }
            
            // User not found in any role
            DispatchQueue.main.async {
                self.errorMessage = "User role not found"
                self.logout()
                self.isLoading = false
            }
        } withCancel: { [weak self] error in
            self?.handleDatabaseError(error)
        }
    }
    
    private func updateUserData(from userData: [String: Any]) {
        DispatchQueue.main.async {
            self.fullName = userData["fullName"] as? String
            self.phoneNumber = userData["phone"] as? String
        }
    }
    
    private func handleDatabaseError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Database error: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    func logout() {
        // First reset all user data
        isAuthenticated = false
        currentUserRole = nil
        documentStatus = .notSubmitted
        fullName = nil
        phoneNumber = nil
        
        // Post a notification to indicate logout
        print("DEBUG: User logged out, posting notification")
        NotificationCenter.default.post(
            name: Notification.Name("UserDidLogout"),
            object: nil
        )
        
        // Now sign out from Firebase Auth last
        do {
            try auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
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
        
        // Phone number validation - stripped down to just 10 digits as a safety check
        let strippedPhone = phoneNumber.filter { "0123456789".contains($0) }
        guard strippedPhone.count == 10 else {
            errorMessage = "Phone number must be exactly 10 digits"
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
        
        if role == .restaurant {
            let storeInfo: [String: Any] = [
                "name": fullName,
                "email": email,
                "phone": phone,
                "description": "Delicious handcrafted food made with fresh, locally-sourced ingredients.",
                "address": "",
                "price_range": [
                    "min": 5,
                    "max": 25
                ]
            ]
            
            let restaurantData: [String: Any] = [
                "role": role.rawValue,
                "store_info": storeInfo,
                "documentsSubmitted": false,
                "isOpen": false,
                "createdAt": ServerValue.timestamp()
            ]
            
            db.child("restaurants").child(userId).setValue(restaurantData) { [weak self] error, _ in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Failed to save user data: \(error.localizedDescription)"
                        return
                    }
                    
                    self.showSuccessMessage = true
                    self.currentUserRole = role
                    self.documentStatus = .notSubmitted
                    self.isAuthenticated = true
                }
            }
        } else {
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
                    self.isAuthenticated = true
                }
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
    
    // Add function to explicitly load user profile data
    func loadUserProfile() {
        guard let userId = currentUserId else {
            print("Cannot load profile: No user ID found")
            return
        }
        
        print("Loading user profile for ID: \(userId)")
        
        // First try to get user role
        if let role = currentUserRole {
            // We know the role, load from the correct path
            let rolePath = "\(role.rawValue.lowercased())s"
            let userRef = db.child(rolePath).child(userId)
            
            userRef.observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let self = self, snapshot.exists() else {
                    print("User data not found at path: \(rolePath)/\(userId)")
                    return
                }
                
                print("Found user data in \(rolePath)")
                if let userData = snapshot.value as? [String: Any] {
                    self.updateUserData(from: userData)
                    
                    // Check if the user is a customer and is blocked
                    if role == .customer {
                        if let isBlocked = userData["blocked"] as? Bool, isBlocked {
                            print("User is blocked and cannot use the app: \(userId)")
                            DispatchQueue.main.async {
                                self.errorMessage = "Your account has been blocked. Please contact support for assistance."
                                // Log the user out since they're blocked
                                self.logout()
                            }
                            return
                        }
                    }
                    
                    // For restaurants, also check store_info
                    if role == .restaurant {
                        if let storeInfo = snapshot.childSnapshot(forPath: "store_info").value as? [String: Any] {
                            DispatchQueue.main.async {
                                self.fullName = storeInfo["name"] as? String ?? self.fullName
                                self.phoneNumber = storeInfo["phone"] as? String ?? self.phoneNumber
                            }
                        }
                    }
                }
            }
        } else {
            // We don't know the role, try all possible paths
            print("User role unknown, checking all paths")
            checkUserRoleAndRedirect(userId: userId)
        }
    }
} 
