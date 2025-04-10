import UIKit
import Firebase
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import GoogleMaps

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize Google Maps
        GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
        
        // Request notification permission
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()
        
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Initialize scheduled orders service
        initializeScheduledOrdersService()
        
        // Register for application lifecycle notifications to check user block status
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, 
            object: nil
        )
        
        return true
    }
    
    @objc func applicationWillEnterForeground() {
        print("App will enter foreground - checking user block status")
        checkCurrentUserBlockStatus()
    }
    
    private func checkCurrentUserBlockStatus() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user logged in, skipping block status check")
            return
        }
        
        print("Checking block status for user: \(userId)")
        
        // We need to check all possible user collections since we don't know what type this user is
        let database = Database.database().reference()
        
        // Check customers first
        database.child("customers").child(userId).child("blocked").observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists(), let isBlocked = snapshot.value as? Bool, isBlocked {
                print("User is BLOCKED in customers collection")
                self.forceLogoutBlockedUser()
                return
            } else {
                // Check drivers
                database.child("drivers").child(userId).child("blocked").observeSingleEvent(of: .value) { snapshot in
                    if snapshot.exists(), let isBlocked = snapshot.value as? Bool, isBlocked {
                        print("User is BLOCKED in drivers collection")
                        self.forceLogoutBlockedUser()
                        return
                    } else {
                        // Check restaurants
                        database.child("restaurants").child(userId).child("blocked").observeSingleEvent(of: .value) { snapshot in
                            if snapshot.exists(), let isBlocked = snapshot.value as? Bool, isBlocked {
                                print("User is BLOCKED in restaurants collection")
                                self.forceLogoutBlockedUser()
                                return
                            }
                            
                            print("User is not blocked in any collection")
                        }
                    }
                }
            }
        }
    }
    
    private func forceLogoutBlockedUser() {
        print("Forcing logout of blocked user")
        
        // Sign out from Firebase Auth
        do {
            try Auth.auth().signOut()
            
            // Post logout notification
            NotificationCenter.default.post(
                name: Notification.Name("UserDidLogout"),
                object: nil
            )
        } catch {
            print("Error signing out blocked user: \(error.localizedDescription)")
        }
    }
    
    private func initializeScheduledOrdersService() {
        // Start timer to process scheduled orders
        ScheduledOrderService.shared.startScheduledOrdersTimer()
        
        // Immediately check for any pending scheduled orders
        ScheduledOrderService.shared.processScheduledOrders()
        
        print("Scheduled orders service initialized")
    }
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Required UIApplicationDelegate methods
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        // Handle remote notification
        if let orderId = userInfo["orderId"] as? String,
           let status = userInfo["status"] as? String {
            NotificationCenter.default.post(
                name: Notification.Name("OrderStatusChanged"),
                object: nil,
                userInfo: [
                    "orderId": orderId,
                    "newStatus": status
                ]
            )
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // Handle the notification data
        if let orderId = userInfo["orderId"] as? String,
           let status = userInfo["status"] as? String {
            NotificationCenter.default.post(
                name: Notification.Name("OrderStatusChanged"),
                object: nil,
                userInfo: [
                    "orderId": orderId,
                    "newStatus": status
                ]
            )
        }
        
        // Show the notification when app is in foreground
        completionHandler([[.banner, .sound]])
    }
    
    // Handle notification when user taps on it
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle the notification data
        if let orderId = userInfo["orderId"] as? String,
           let status = userInfo["status"] as? String {
            NotificationCenter.default.post(
                name: Notification.Name("OrderStatusChanged"),
                object: nil,
                userInfo: [
                    "orderId": orderId,
                    "newStatus": status
                ]
            )
        }
        
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("DEBUG: 📱 NOTIFICATION - Firebase registration token received: \(fcmToken ?? "nil")")
        
        // Store FCM token in Firebase for the current user
        if let token = fcmToken,
           let userId = Auth.auth().currentUser?.uid {
            let database = Database.database().reference()
            
            print("DEBUG: 📱 NOTIFICATION - Storing FCM token for user: \(userId)")
            
            // Store token in multiple locations to ensure it can be found
            // 1. In users collection
            database.child("users").child(userId).child("fcmToken").setValue(token) { error, _ in
                if let error = error {
                    print("DEBUG: ❌ NOTIFICATION - Failed to store token in users: \(error.localizedDescription)")
                } else {
                    print("DEBUG: ✅ NOTIFICATION - Successfully stored FCM token in users collection")
                }
            }
            
            // 2. In customers collection
            database.child("customers").child(userId).child("fcmToken").setValue(token) { error, _ in
                if let error = error {
                    print("DEBUG: ❌ NOTIFICATION - Failed to store token in customers: \(error.localizedDescription)")
                } else {
                    print("DEBUG: ✅ NOTIFICATION - Successfully stored FCM token in customers collection")
                }
            }
            
            // 3. In device_tokens collection (as a backup)
            database.child("device_tokens").child(userId).setValue(token) { error, _ in
                if let error = error {
                    print("DEBUG: ❌ NOTIFICATION - Failed to store token in device_tokens: \(error.localizedDescription)")
                } else {
                    print("DEBUG: ✅ NOTIFICATION - Successfully stored FCM token in device_tokens collection")
                }
            }
            
            // Store token in UserDefaults for local use
            UserDefaults.standard.set(token, forKey: "fcmToken")
        }
    }
} 