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
            updates["orderStatus"] = "driver_accepted"
            updates["acceptedTime"] = ServerValue.timestamp()
            
            // After accepting, set status to ready_for_pickup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                orderRef.updateChildValues([
                    "status": OrderStatus.pickedUp.rawValue,
                    "orderStatus": "ready_for_pickup"
                ])
            }
            
        case .pickedUp:
            updates["orderStatus"] = "on_the_way"
            updates["pickedUpTime"] = ServerValue.timestamp()
            
        case .delivered:
            updates["orderStatus"] = "completed"
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
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        let orderRef = database.child("orders").child(orderId)
        
        let updates: [String: Any] = [
            "status": "pending",
            "order_status": "pending",
            "driverId": NSNull(),
            "driverName": NSNull(),
            "rejectedBy": [userId: true]  // Keep track of drivers who rejected this order
        ]
        
        orderRef.updateChildValues(updates) { [weak self] error, _ in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.error = "Error rejecting order: \(error.localizedDescription)"
                }
            }
        }
        
        // Clear the driver's currentOrderId
        database.child("drivers").child(userId).updateChildValues([
            "currentOrderId": NSNull()
        ])
    }
} 