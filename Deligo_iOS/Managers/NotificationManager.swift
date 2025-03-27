import Foundation
import FirebaseDatabase
import FirebaseMessaging

class NotificationManager {
    static let shared = NotificationManager()
    private let database = Database.database().reference()
    private let serverKey = "AAAA4Ue_Xtg:APA91bFXIe0yO-7oVEU7tF7AcQD4Rr6VxYfMBdL-mU_BEYGRVOYd-QGBFxz-UBJXIe_24vDYoqX2K4pGYO_MRDQIYs_bNvqNBbqGxjHPQIhvQ0K_KgxKHCLXDF9UhGiJ-5GRlZQjhVTR" // Your FCM Server Key
    
    private init() {}
    
    func sendPushNotification(to userId: String, title: String, body: String, data: [String: String]) {
        print("DEBUG: 📱 NOTIFICATION - Attempting to send push notification to user: \(userId)")
        
        // First, try looking up FCM token in the users collection
        database.child("users").child(userId).child("fcmToken").observeSingleEvent(of: .value) { [weak self] snapshot, _ in
            guard let self = self else { return }
            
            if let token = snapshot.value as? String, !token.isEmpty {
                print("DEBUG: 📱 NOTIFICATION - Found FCM token in users collection: \(token.prefix(10))...")
                self.sendNotificationWithToken(token, title: title, body: body, data: data)
                return
            }
            
            print("DEBUG: 📱 NOTIFICATION - No valid FCM token found in users/\(userId)/fcmToken")
            
            // If not found in users, try in customers collection
            self.database.child("customers").child(userId).child("fcmToken").observeSingleEvent(of: .value) { [weak self] customerSnapshot, _ in
                guard let self = self else { return }
                
                if let customerToken = customerSnapshot.value as? String, !customerToken.isEmpty {
                    print("DEBUG: 📱 NOTIFICATION - Found FCM token in customers collection: \(customerToken.prefix(10))...")
                    self.sendNotificationWithToken(customerToken, title: title, body: body, data: data)
                    return
                }
                
                print("DEBUG: 📱 NOTIFICATION - No valid FCM token found in customers/\(userId)/fcmToken")
                
                // Final attempt - try in device_tokens collection
                self.database.child("device_tokens").child(userId).observeSingleEvent(of: .value) { [weak self] tokenSnapshot, _ in
                    guard let self = self else { return }
                    
                    if let deviceToken = tokenSnapshot.value as? String, !deviceToken.isEmpty {
                        print("DEBUG: 📱 NOTIFICATION - Found FCM token in device_tokens: \(deviceToken.prefix(10))...")
                        self.sendNotificationWithToken(deviceToken, title: title, body: body, data: data)
                    } else {
                        print("DEBUG: ❌ NOTIFICATION - Failed to find any valid FCM token for user \(userId)")
                        print("DEBUG: ❌ NOTIFICATION - Notification could not be delivered")
                    }
                }
            }
        }
    }
    
    private func sendNotificationWithToken(_ token: String, title: String, body: String, data: [String: String]) {
        let notification = [
            "to": token,
            "notification": [
                "title": title,
                "body": body,
                "sound": "default",
                "badge": 1,
                "content_available": true
            ],
            "data": data,
            "priority": "high"
        ] as [String : Any]
        
        print("DEBUG: 📱 NOTIFICATION - Sending notification payload to FCM")
        
        self.sendToFCM(notification: notification) { success in
            if success {
                print("DEBUG: ✅ NOTIFICATION - Successfully sent notification to FCM")
                
                // Store the notification in Firebase for the user
                let notificationRef = self.database.child("notifications").child(data["orderId"] ?? "unknown").childByAutoId()
                notificationRef.setValue([
                    "title": title,
                    "body": body,
                    "data": data,
                    "timestamp": ServerValue.timestamp(),
                    "read": false
                ])
            } else {
                print("DEBUG: ❌ NOTIFICATION - Failed to send notification to FCM")
            }
        }
    }
    
    private func sendToFCM(notification: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://fcm.googleapis.com/fcm/send") else {
            print("DEBUG: ❌ NOTIFICATION - Invalid FCM URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: notification)
            print("DEBUG: 📱 NOTIFICATION - Sending HTTP request to FCM")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("DEBUG: ❌ NOTIFICATION - FCM request failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("DEBUG: 📊 NOTIFICATION - FCM response status: \(httpResponse.statusCode)")
                    
                    // Print response body for debugging
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("DEBUG: 📝 NOTIFICATION - FCM response body: \(responseString)")
                    }
                    
                    completion(httpResponse.statusCode == 200)
                } else {
                    print("DEBUG: ❌ NOTIFICATION - Invalid response from FCM")
                    completion(false)
                }
            }.resume()
        } catch {
            print("DEBUG: ❌ NOTIFICATION - Failed to serialize notification: \(error.localizedDescription)")
            completion(false)
        }
    }
} 