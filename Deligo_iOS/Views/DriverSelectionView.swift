import SwiftUI
import FirebaseDatabase

struct DriverSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var availableDrivers = [Driver]()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDriverId: String?
    let orderId: String
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading available drivers...")
                } else if let error = errorMessage {
                    VStack {
                        Text("Error loading drivers")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            loadAvailableDrivers()
                        }
                        .padding()
                        .background(Color(hex: "F4A261"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.top)
                    }
                } else if availableDrivers.isEmpty {
                    VStack {
                        Text("No available drivers")
                            .font(.headline)
                        
                        Text("There are no drivers available at the moment.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    List {
                        ForEach(availableDrivers) { driver in
                            DriverRow(
                                driver: driver,
                                isSelected: selectedDriverId == driver.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDriverId = driver.id
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    Button("Assign Selected Driver") {
                        if let driverId = selectedDriverId {
                            assignDriverToOrder(driverId: driverId)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedDriverId == nil ? Color.gray : Color(hex: "F4A261"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .disabled(selectedDriverId == nil)
                }
            }
            .navigationTitle("Select Driver")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                loadAvailableDrivers()
            }
        }
    }
    
    private func loadAvailableDrivers() {
        isLoading = true
        errorMessage = nil
        availableDrivers = []
        
        let database = Database.database().reference()
        database.child("drivers")
            .queryOrdered(byChild: "isAvailable")
            .queryEqual(toValue: true)
            .observeSingleEvent(of: .value) { snapshot in
                guard snapshot.exists() else {
                    DispatchQueue.main.async {
                        isLoading = false
                    }
                    return
                }
                
                var drivers = [Driver]()
                
                for child in snapshot.children {
                    if let snapshot = child as? DataSnapshot,
                       let data = snapshot.value as? [String: Any] {
                        
                        // Check if driver already has an active order
                        let currentOrderId = data["currentOrderId"] as? String
                        
                        // Get driver name from different possible locations
                        var driverName = "Unknown Driver"
                        var phone = "No Phone"
                        
                        if let userInfo = data["user_info"] as? [String: Any] {
                            driverName = userInfo["fullName"] as? String ?? driverName
                            phone = userInfo["phone"] as? String ?? phone
                        } else {
                            driverName = data["fullName"] as? String ?? driverName
                            phone = data["phone"] as? String ?? phone
                            
                            if driverName == "Unknown Driver", 
                               let firstName = data["firstName"] as? String,
                               let lastName = data["lastName"] as? String {
                                driverName = "\(firstName) \(lastName)"
                            }
                        }
                        
                        let driver = Driver(
                            id: snapshot.key,
                            name: driverName,
                            phone: phone,
                            rating: data["rating"] as? Double ?? 0.0,
                            totalRides: data["totalRides"] as? Int ?? 0,
                            isAvailable: true,
                            currentOrderId: currentOrderId
                        )
                        
                        drivers.append(driver)
                    }
                }
                
                DispatchQueue.main.async {
                    availableDrivers = drivers
                    isLoading = false
                }
            } withCancel: { error in
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
    }
    
    private func assignDriverToOrder(driverId: String) {
        isLoading = true
        
        let database = Database.database().reference()
        let orderRef = database.child("orders").child(orderId)
        
        // Update order with driver ID and correct status values
        orderRef.updateChildValues([
            "driverId": driverId,
            "status": "in_progress",
            "order_status": "assigned_driver",
            "updatedAt": ServerValue.timestamp()
        ]) { error, _ in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to assign driver: \(error.localizedDescription)"
                }
                return
            }
            
            // Update driver with current order ID and set availability to false
            database.child("drivers").child(driverId).updateChildValues([
                "currentOrderId": orderId,
                "isAvailable": false
            ]) { error, _ in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = "Failed to update driver: \(error.localizedDescription)"
                    } else {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct DriverRow: View {
    let driver: Driver
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.headline)
                
                HStack {
                    Text("Rating: \(String(format: "%.1f", driver.rating))")
                        .font(.subheadline)
                    
                    Text("•")
                    
                    Text("Rides: \(driver.totalRides)")
                        .font(.subheadline)
                }
                .foregroundColor(.gray)
                
                Text(driver.phone)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "F4A261"))
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color(hex: "F4A261").opacity(0.1) : Color.clear)
    }
}

#Preview {
    DriverSelectionView(orderId: "123")
} 