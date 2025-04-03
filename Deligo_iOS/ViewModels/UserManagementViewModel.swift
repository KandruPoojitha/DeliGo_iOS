import Foundation
import FirebaseDatabase
import Combine

class UserManagementViewModel: ObservableObject {
    @Published var users: [UserData] = []
    @Published var isLoading = false
    private let db = Database.database().reference()
    
    func fetchUsers(for role: UserRole) {
        isLoading = true
        users.removeAll()
        
        let rolePath = "\(role.rawValue.lowercased())s"
        print("Fetching users from path: \(rolePath)")
        
        db.child(rolePath).observeSingleEvent(of: .value) { [weak self] snapshot, _ in
            guard let self = self else { return }
            
            var fetchedUsers: [UserData] = []
            
            guard let snapshots = snapshot.children.allObjects as? [DataSnapshot] else {
                self.isLoading = false
                return
            }
            
            for snapshot in snapshots {
                guard let userData = snapshot.value as? [String: Any] else {
                    continue
                }
                
                let userId = snapshot.key
                let fullName = userData["fullName"] as? String ?? "No Name"
                let email = userData["email"] as? String ?? "No Email"
                let phone = userData["phone"] as? String ?? "No Phone"
                let blocked = userData["blocked"] as? Bool ?? false
                
                print("🔍 User: \(fullName) (ID: \(userId)) - Blocked status: \(blocked)")
                
                var documentStatus: String?
                var documentsSubmitted: Bool?
                var restaurantProofURL: String?
                var ownerIDURL: String?
                var businessHours: BusinessHours?
                var governmentIDURL: String?
                var driverLicenseURL: String?
                
                // Fetch document data
                if let documents = userData["documents"] as? [String: Any] {
                    documentStatus = documents["status"] as? String
                    
                    if role == .restaurant {
                        if let restaurantProof = documents["restaurant_proof"] as? [String: Any] {
                            restaurantProofURL = restaurantProof["url"] as? String
                        }
                        if let ownerID = documents["owner_id"] as? [String: Any] {
                            ownerIDURL = ownerID["url"] as? String
                        }
                    } else if role == .driver {
                        if let govtID = documents["govt_id"] as? [String: Any] {
                            governmentIDURL = govtID["url"] as? String
                        }
                        if let license = documents["license"] as? [String: Any] {
                            driverLicenseURL = license["url"] as? String
                        }
                    }
                }
                
                documentsSubmitted = userData["documentsSubmitted"] as? Bool
                
                if role == .restaurant {
                    if let hours = userData["hours"] as? [String: String] {
                        businessHours = BusinessHours(
                            opening: hours["opening"] ?? "N/A",
                            closing: hours["closing"] ?? "N/A"
                        )
                    }
                }
                
                let user = UserData(
                    id: snapshot.key,
                    fullName: fullName,
                    email: email,
                    phone: phone,
                    role: role,
                    blocked: blocked,
                    documentStatus: documentStatus,
                    documentsSubmitted: documentsSubmitted,
                    restaurantProofURL: restaurantProofURL,
                    ownerIDURL: ownerIDURL,
                    businessHours: businessHours,
                    governmentIDURL: governmentIDURL,
                    driverLicenseURL: driverLicenseURL
                )
                fetchedUsers.append(user)
            }
            
            DispatchQueue.main.async {
                self.users = fetchedUsers
                self.isLoading = false
                print("Fetched \(fetchedUsers.count) users for role: \(role.rawValue)")
            }
        }
    }
    
    func updateDocumentStatus(userId: String, userRole: UserRole, status: String, completion: @escaping (Error?) -> Void) {
        let rolePath = "\(userRole.rawValue.lowercased())s"
        let updates = [
            "documents/status": status
        ]
        
        db.child(rolePath).child(userId).updateChildValues(updates) { error, _ in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error)
                } else {
                    // Update the local users array
                    if let index = self.users.firstIndex(where: { $0.id == userId }) {
                        self.users[index].documentStatus = status
                    }
                    completion(nil)
                }
            }
        }
    }
    
    func toggleUserBlock(userId: String, userRole: UserRole, currentBlocked: Bool, completion: @escaping (Error?) -> Void) {
        let rolePath = "\(userRole.rawValue.lowercased())s"
        let newBlockedStatus = !currentBlocked
        
        print("DEBUG: 🔒 Toggling block status for \(userRole.rawValue) user: \(userId)")
        print("DEBUG: Current status: \(currentBlocked), New status: \(newBlockedStatus)")
        
        // First verify the user exists
        db.child(rolePath).child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if !snapshot.exists() {
                let error = NSError(domain: "", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "User not found"])
                completion(error)
                return
            }
            
            // Prepare updates
            let updates = [
                "blocked": newBlockedStatus,
                "updatedAt": ServerValue.timestamp()
            ] as [String : Any]
            
            // Update the user's blocked status
            db.child(rolePath).child(userId).updateChildValues(updates) { error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        print("DEBUG: ❌ Error updating block status: \(error.localizedDescription)")
                        completion(error)
                    } else {
                        print("DEBUG: ✅ Successfully updated block status")
                        
                        // Update the local users array
                        if let index = self.users.firstIndex(where: { $0.id == userId }) {
                            self.users[index].blocked = newBlockedStatus
                            
                            // Post notifications for UI updates
                            NotificationCenter.default.post(
                                name: Notification.Name("UserBlockStatusChanged"),
                                object: nil,
                                userInfo: [
                                    "userId": userId,
                                    "isBlocked": newBlockedStatus,
                                    "userRole": userRole.rawValue
                                ]
                            )
                            
                            NotificationCenter.default.post(
                                name: Notification.Name("UserModelUpdated"),
                                object: nil
                            )
                        }
                        
                        // If blocking a restaurant, update their isOpen status to false
                        if userRole == .restaurant && newBlockedStatus {
                            self.db.child(rolePath).child(userId).updateChildValues(["isOpen": false])
                        }
                        
                        completion(nil)
                    }
                }
            }
        }
    }
} 
