import Foundation
import FirebaseDatabase
import FirebaseAuth
import Combine

class DriverHomeViewModel: ObservableObject {
    @Published var isAvailable = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let database = Database.database().reference()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupDriverStatusListener()
    }
    
    private func setupDriverStatusListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        database.child("drivers").child(userId).child("isAvailable")
            .observe(.value) { [weak self] snapshot in
                if let isAvailable = snapshot.value as? Bool {
                    DispatchQueue.main.async {
                        self?.isAvailable = isAvailable
                    }
                }
            }
    }
    
    func updateDriverAvailability(_ available: Bool) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        database.child("drivers").child(userId).updateChildValues([
            "isAvailable": available
        ]) { [weak self] error, _ in
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = "Error updating availability: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func updateOrderStatus(orderId: String, status: OrderStatus) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        let orderRef = database.child("orders").child(orderId)
        
        // Different fields to update based on status
        var updates: [String: Any] = ["status": status.rawValue]
        
        switch status {
        case .accepted:
            updates["status"] = "in_progress"
            updates["order_status"] = "driver_accepted"
            updates["acceptedTime"] = ServerValue.timestamp()
            
            // Get order details to send notification
            orderRef.observeSingleEvent(of: .value) { [weak self] snapshot in
                if let orderData = snapshot.value as? [String: Any],
                   let userId = orderData["userId"] as? String,
                   let restaurantName = orderData["restaurantName"] as? String {
                    
                    // Send push notification to customer
                    NotificationManager.shared.sendPushNotification(
                        to: userId,
                        title: "Order Accepted!",
                        body: "Your order from \(restaurantName) has been accepted by the driver.",
                        data: [
                            "orderId": orderId,
                            "status": "in_progress",
                            "orderStatus": "driver_accepted",
                            "type": "order_accepted"
                        ]
                    )
                    
                    // Post local notification
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("OrderStatusChanged"),
                            object: nil,
                            userInfo: [
                                "orderId": orderId,
                                "newStatus": "in_progress",
                                "newOrderStatus": "driver_accepted"
                            ]
                        )
                    }
                }
            }
            
        case .pickedUp:
            updates["status"] = "in_progress"
            updates["order_status"] = "picked_up"
            updates["pickedUpTime"] = ServerValue.timestamp()
            
            // Get order details to send notification
            orderRef.observeSingleEvent(of: .value) { [weak self] snapshot in
                if let orderData = snapshot.value as? [String: Any],
                   let userId = orderData["userId"] as? String,
                   let restaurantName = orderData["restaurantName"] as? String {
                    
                    // Send push notification to customer
                    NotificationManager.shared.sendPushNotification(
                        to: userId,
                        title: "Order Picked Up!",
                        body: "Your order from \(restaurantName) has been picked up and is on its way to you.",
                        data: [
                            "orderId": orderId,
                            "status": "in_progress",
                            "orderStatus": "picked_up",
                            "type": "order_picked_up"
                        ]
                    )
                    
                    // Post local notification
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("OrderStatusChanged"),
                            object: nil,
                            userInfo: [
                                "orderId": orderId,
                                "newStatus": "in_progress",
                                "newOrderStatus": "picked_up"
                            ]
                        )
                    }
                }
            }
            
        case .delivered:
            updates["status"] = "delivered"
            updates["order_status"] = "delivered"
            updates["deliveredTime"] = ServerValue.timestamp()
            
            // Clear the driver's currentOrderId when order is delivered
            database.child("drivers").child(userId).updateChildValues([
                "currentOrderId": NSNull()
            ])
            
        default:
            break
        }
        
        orderRef.updateChildValues(updates) { [weak self] error, _ in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.error = "Error updating order status: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func rejectOrder(orderId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: No user ID found")
            return
        }
        
        print("Starting order rejection for orderId: \(orderId)")
        let orderRef = database.child("orders").child(orderId)
        let driverRef = database.child("drivers").child(userId)
        
        // First, verify the order exists and get its current state
        orderRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else {
                print("Error: Self is nil")
                return
            }
            
            if !snapshot.exists() {
                print("Error: Order not found in Firebase")
                return
            }
            
            print("Order found in Firebase, current data: \(snapshot.value ?? "nil")")
            
            // Update the order status and remove driver info
            let updates: [String: Any] = [
                "status": "in_progress",
                "order_status": "ready_for_pickup",
                "driverId": NSNull(),
                "driverName": NSNull()
            ]
            
            print("Attempting to update order with: \(updates)")
            
            orderRef.updateChildValues(updates) { error, _ in
                if let error = error {
                    print("Error updating order in Firebase: \(error.localizedDescription)")
                    return
                }
                
                print("Order updated successfully in Firebase")
                
                print("Updating driver's rejection count and availability...")
                // Update the driver's rejectedOrdersCount and set isAvailable to true
                driverRef.observeSingleEvent(of: .value) { snapshot in
                    if let driverData = snapshot.value as? [String: Any] {
                        let currentCount = driverData["rejectedOrdersCount"] as? Int ?? 0
                        print("Current rejection count: \(currentCount)")
                        
                        let driverUpdates: [String: Any] = [
                            "rejectedOrdersCount": currentCount + 1,
                            "currentOrderId": NSNull(),
                            "isAvailable": true
                        ]
                        
                        print("Updating driver with: \(driverUpdates)")
                        
                        driverRef.updateChildValues(driverUpdates) { error, _ in
                            if let error = error {
                                print("Error updating driver in Firebase: \(error.localizedDescription)")
                            } else {
                                print("Driver updated successfully in Firebase")
                            }
                        }
                    } else {
                        print("No driver data found, initializing rejection count")
                        let driverUpdates: [String: Any] = [
                            "rejectedOrdersCount": 1,
                            "currentOrderId": NSNull(),
                            "isAvailable": true
                        ]
                        
                        driverRef.updateChildValues(driverUpdates) { error, _ in
                            if let error = error {
                                print("Error initializing driver rejection count in Firebase: \(error.localizedDescription)")
                            } else {
                                print("Driver initialized successfully in Firebase")
                            }
                        }
                    }
                }
            }
        }
    }
} 