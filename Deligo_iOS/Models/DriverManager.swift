import Foundation
import FirebaseDatabase

class DriverManager: ObservableObject {
    @Published var availableDrivers: [DeliveryDriverInfo] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db: DatabaseReference
    
    init() {
        self.db = Database.database().reference()
    }
    
    func loadAvailableDrivers() {
        isLoading = true
        error = nil
        
        // Clear existing drivers before loading new ones
        availableDrivers = []
        
        print("Fetching fresh driver data from Firebase...")
        
        // Use observeSingleEvent instead of observe to get data once rather than setting up a listener
        db.child("drivers").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var drivers: [DeliveryDriverInfo] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let dict = snapshot.value as? [String: Any],
                      let isAvailable = dict["isAvailable"] as? Bool,
                      isAvailable else { continue }
                
                let driver = DeliveryDriverInfo(
                    id: snapshot.key,
                    name: dict["name"] as? String ?? "",
                    phone: dict["phone"] as? String ?? "",
                    isAvailable: isAvailable,
                    currentLocation: dict["currentLocation"] as? [String: Double] ?? [:],
                    rating: dict["rating"] as? Double ?? 0.0,
                    totalDeliveries: dict["totalDeliveries"] as? Int ?? 0
                )
                drivers.append(driver)
            }
            
            DispatchQueue.main.async {
                self.availableDrivers = drivers
                self.isLoading = false
                print("Loaded \(drivers.count) available drivers from Firebase")
            }
        }
    }
    
    func assignDriver(driverId: String, orderId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        // Update driver's availability only - don't set currentOrderId
        db.child("drivers").child(driverId).updateChildValues([
            "isAvailable": false
        ]) { [weak self] error, _ in
            guard let self = self else { return }
            
            if let error = error {
                print("Error assigning driver: \(error.localizedDescription)")
                self.error = "Failed to assign driver: \(error.localizedDescription)"
                completion(false)
            } else {
                completion(true)
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}

struct DeliveryDriverInfo: Identifiable {
    let id: String
    let name: String
    let phone: String
    let isAvailable: Bool
    let currentLocation: [String: Double]
    let rating: Double
    let totalDeliveries: Int
} 