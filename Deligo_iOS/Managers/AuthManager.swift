import Foundation
import FirebaseAuth

class AuthManager {
    static let shared = AuthManager()
    
    private init() {}
    
    func getAuthToken() -> String? {
        // Get the current Firebase user's ID token
        if let currentUser = Auth.auth().currentUser {
            var token: String?
            let semaphore = DispatchSemaphore(value: 0)
            
            currentUser.getIDToken { idToken, error in
                if let error = error {
                    print("Error getting ID token: \(error.localizedDescription)")
                    token = nil
                } else {
                    token = idToken
                }
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 5.0) // Wait up to 5 seconds for token
            return token
        }
        return nil
    }
} 