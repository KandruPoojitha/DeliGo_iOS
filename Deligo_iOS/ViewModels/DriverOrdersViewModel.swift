import Foundation
import FirebaseDatabase
import Combine

class DriverOrdersViewModel: ObservableObject {
    @Published var assignedOrders: [DriverOrder] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let database = Database.database().reference()
    private let driverId: String
    private var ordersRef: DatabaseReference
    private var driversRef: DatabaseReference
    private var cancellables = Set<AnyCancellable>()
    
    init(driverId: String) {
        self.driverId = driverId
        self.ordersRef = database.child("orders")
        self.driversRef = database.child("drivers")
        
        print("DriverOrdersViewModel initialized for driver: \(driverId)")
        loadAssignedOrders()
    }
    
    func loadAssignedOrders() {
        guard !driverId.isEmpty else {
            error = "Invalid driver ID"
            return
        }
        
        isLoading = true
        print("Loading assigned orders for driver: \(driverId)")
        
        // Check connection status
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value) { [weak self] (snapshot: DataSnapshot) in
            guard let self = self else { return }
            
            if let connected = snapshot.value as? Bool, !connected {
                self.error = "No internet connection. Some features may be limited."
                self.isLoading = false
                return
            }
            
            // Query orders assigned to this driver
            self.ordersRef
                .queryOrdered(byChild: "driverId")
                .queryEqual(toValue: self.driverId)
                .observe(.value) { [weak self] (snapshot: DataSnapshot) in
                    guard let self = self else { return }
                    
                    var orders: [DriverOrder] = []
                    
                    for child in snapshot.children {
                        guard let snapshot = child as? DataSnapshot,
                              let orderData = snapshot.value as? [String: Any] else { continue }
                        
                        // Only include orders that are not completed or cancelled
                        let status = orderData["status"] as? String ?? ""
                        if status != "delivered" && status != "cancelled" {
                            let order = DriverOrder(id: snapshot.key, data: orderData)
                            orders.append(order)
                        }
                    }
                    
                    // Also query for orders with order_status "assigned_driver" that might not have driver ID set yet
                    self.ordersRef
                        .queryOrdered(byChild: "order_status")
                        .queryEqual(toValue: "assigned_driver")
                        .observeSingleEvent(of: .value) { assignedSnapshot in
                            
                            for child in assignedSnapshot.children {
                                guard let snapshot = child as? DataSnapshot,
                                      let orderData = snapshot.value as? [String: Any] else { continue }
                                
                                // Check if this order is already in our list
                                let orderId = snapshot.key
                                if !orders.contains(where: { $0.id == orderId }) {
                                    let order = DriverOrder(id: snapshot.key, data: orderData)
                                    orders.append(order)
                                    
                                    // Automatically assign this driver to the order
                                    self.assignDriverToOrder(orderId: orderId)
                                }
                            }
                            
                            // Sort orders by assignment time (most recent first)
                            orders.sort { $0.createdAt > $1.createdAt }
                            
                            DispatchQueue.main.async {
                                self.assignedOrders = orders
                                self.isLoading = false
                            }
                        }
                }
        }
    }
    
    // Helper method to assign the driver to an order
    private func assignDriverToOrder(orderId: String) {
        let updates: [String: Any] = [
            "driverId": driverId,
            "status": "in_progress",
            "order_status": "assigned_driver",
            "updatedAt": ServerValue.timestamp()
        ]
        
        ordersRef.child(orderId).updateChildValues(updates) { error, _ in
            if let error = error {
                print("Error assigning driver to order: \(error.localizedDescription)")
            } else {
                print("Successfully assigned driver to order: \(orderId)")
            }
        }
    }
    
    func updateOrderStatus(orderId: String, status: OrderStatus) {
        isLoading = true
        
        var updates: [String: Any] = [
            "updatedAt": ServerValue.timestamp()
        ]
        
        // If the status is "accepted", set initial status to in_progress
        if status == .accepted {
            updates["status"] = "in_progress"
            updates["order_status"] = "driver_accepted"
            
            // Get order details to send notification
            ordersRef.child(orderId).observeSingleEvent(of: .value) { [weak self] snapshot in
                if let orderData = snapshot.value as? [String: Any],
                   let userId = orderData["userId"] as? String,
                   let restaurantName = orderData["restaurantName"] as? String {
                    
                    // Send push notification to customer
                    NotificationManager.shared.sendPushNotification(
                        to: userId,
                        title: "Order Accepted!",
                        body: "Your order from \(restaurantName) has been accepted and is being prepared.",
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
        } else if status == .cancelled {
            updates["status"] = "cancelled"
            updates["order_status"] = "rejected"
            
            // Get order details to send notification
            ordersRef.child(orderId).observeSingleEvent(of: .value) { [weak self] snapshot in
                if let orderData = snapshot.value as? [String: Any],
                   let userId = orderData["userId"] as? String,
                   let restaurantName = orderData["restaurantName"] as? String {
                    
                    // Send push notification to customer
                    NotificationManager.shared.sendPushNotification(
                        to: userId,
                        title: "Order Rejected",
                        body: "Your order from \(restaurantName) has been rejected by the driver.",
                        data: [
                            "orderId": orderId,
                            "status": "cancelled",
                            "orderStatus": "rejected",
                            "type": "order_rejected"
                        ]
                    )
                    
                    // Post local notification
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("OrderStatusChanged"),
                            object: nil,
                            userInfo: [
                                "orderId": orderId,
                                "newStatus": "cancelled",
                                "newOrderStatus": "rejected"
                            ]
                        )
                    }
                }
            }
        } else if status == .pickedUp {
            updates["order_status"] = "picked_up"
            
            // Get order details to send notification
            ordersRef.child(orderId).observeSingleEvent(of: .value) { [weak self] snapshot in
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
        } else if status == .delivered {
            updates["status"] = "delivered"
            updates["order_status"] = "delivered"
            
            // Get order details to send notification
            ordersRef.child(orderId).observeSingleEvent(of: .value) { [weak self] snapshot in
                if let orderData = snapshot.value as? [String: Any],
                   let userId = orderData["userId"] as? String,
                   let restaurantName = orderData["restaurantName"] as? String {
                    
                    // Send push notification to customer
                    NotificationManager.shared.sendPushNotification(
                        to: userId,
                        title: "Order Delivered!",
                        body: "Your order from \(restaurantName) has been delivered. Enjoy your meal!",
                        data: [
                            "orderId": orderId,
                            "status": "delivered",
                            "orderStatus": "delivered",
                            "type": "order_delivered"
                        ]
                    )
                    
                    // Post local notification
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("OrderStatusChanged"),
                            object: nil,
                            userInfo: [
                                "orderId": orderId,
                                "newStatus": "delivered",
                                "newOrderStatus": "delivered"
                            ]
                        )
                    }
                }
            }
        }
        
        ordersRef.child(orderId).updateChildValues(updates) { [weak self] error, _ in
            guard let self = self else { return }
            
            if let error = error {
                self.isLoading = false
                self.error = "Failed to update order status: \(error.localizedDescription)"
                return
            }
            
            // If the order is delivered, update driver's status
            if status == .delivered {
                self.updateDriverStatusAfterDelivery()
            } else {
                self.isLoading = false
            }
        }
    }
    
    private func updateDriverStatusAfterDelivery() {
        let driverUpdates: [String: Any] = [
            "isAvailable": true,
            "currentOrderId": "",
            "lastDeliveryAt": ServerValue.timestamp()
        ]
        
        driversRef.child(driverId).updateChildValues(driverUpdates) { [weak self] error, _ in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.error = "Failed to update driver status: \(error.localizedDescription)"
            } else {
                print("Driver status updated successfully after delivery")
            }
        }
    }
    
    func estimateDeliveryTime(orderId: String, minutes: Int) {
        let estimatedTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        ordersRef.child(orderId).updateChildValues([
            "estimatedDeliveryTime": estimatedTime.timeIntervalSince1970
        ]) { [weak self] error, _ in
            if let error = error {
                self?.error = "Failed to update estimated delivery time: \(error.localizedDescription)"
            }
        }
    }
} 