import Foundation
import FirebaseDatabase
import Combine

class ScheduledOrderService {
    static let shared = ScheduledOrderService()
    
    private let db = Database.database().reference()
    private var scheduledOrdersRef: DatabaseReference
    private var ordersRef: DatabaseReference
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        scheduledOrdersRef = db.child("scheduled_orders")
        ordersRef = db.child("orders")
    }
    
    // Check for scheduled orders that should be processed
    func processScheduledOrders() {
        let currentTime = Date().timeIntervalSince1970
        
        // Query all scheduled orders
        scheduledOrdersRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            for child in snapshot.children {
                guard let orderSnapshot = child as? DataSnapshot,
                      let orderData = orderSnapshot.value as? [String: Any],
                      let scheduledFor = orderData["scheduledFor"] as? TimeInterval,
                      let restaurantId = orderData["restaurantId"] as? String else {
                    continue
                }
                
                // Check if it's time to process this order
                if scheduledFor <= currentTime {
                    // Check if restaurant is open now
                    self.checkRestaurantStatus(restaurantId: restaurantId) { isOpen in
                        if isOpen {
                            // Process the order (move from scheduled to regular orders)
                            self.moveToRegularOrders(orderSnapshot.key, orderData: orderData)
                        }
                    }
                }
            }
        }
    }
    
    // Check if a restaurant is currently open
    private func checkRestaurantStatus(restaurantId: String, completion: @escaping (Bool) -> Void) {
        db.child("restaurants").child(restaurantId).observeSingleEvent(of: .value) { snapshot in
            if let restaurantData = snapshot.value as? [String: Any],
               let isOpen = restaurantData["isOpen"] as? Bool {
                completion(isOpen)
            } else {
                completion(false)
            }
        }
    }
    
    // Move a scheduled order to the regular orders collection
    private func moveToRegularOrders(_ orderId: String, orderData: [String: Any]) {
        // Create a mutable copy of the order data
        var mutableOrderData = orderData
        
        // Update order status
        mutableOrderData["status"] = "pending"
        mutableOrderData["order_status"] = "pending"
        mutableOrderData["isScheduled"] = false
        
        // Add to regular orders
        ordersRef.child(orderId).setValue(mutableOrderData) { [weak self] error, _ in
            guard let self = self else { return }
            
            if error != nil {
                print("Failed to move scheduled order to regular orders: \(error!.localizedDescription)")
                return
            }
            
            // Order successfully moved, now remove from scheduled orders
            self.scheduledOrdersRef.child(orderId).removeValue { error, _ in
                if error != nil {
                    print("Failed to remove scheduled order after processing: \(error!.localizedDescription)")
                }
            }
            
            // Send notification to customer
            if let userId = mutableOrderData["userId"] as? String,
               let restaurantName = mutableOrderData["restaurantName"] as? String {
                NotificationManager.shared.sendPushNotification(
                    to: userId,
                    title: "Your Scheduled Order is Processing",
                    body: "Your scheduled order from \(restaurantName) is now being processed.",
                    data: [
                        "orderId": orderId,
                        "type": "scheduled_order_processing"
                    ]
                )
            }
        }
    }
    
    // Setup a timer to periodically check scheduled orders
    func startScheduledOrdersTimer() {
        // Check every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processScheduledOrders()
            }
            .store(in: &cancellables)
    }
} 