import SwiftUI
import FirebaseDatabase

// Use our renamed struct
typealias DriverModel = DeliveryDriverInfo

struct RestaurantOrderDetailView: View {
    let order: Order
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var driverManager = DriverManager()
    @State private var showingDriverAssignment = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ... existing order details view ...
                
                if order.status == "confirmed" {
                    Button(action: {
                        driverManager.loadAvailableDrivers()
                        showingDriverAssignment = true
                    }) {
                        Text("Assign Driver")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "F4A261"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("Order Details")
        .sheet(isPresented: $showingDriverAssignment) {
            DriverAssignmentSheet(
                order: order,
                driverManager: driverManager,
                isPresented: $showingDriverAssignment
            )
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Driver Assignment"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct DriverAssignmentSheet: View {
    let order: Order
    @ObservedObject var driverManager: DriverManager
    @Binding var isPresented: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedDriverId: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // Title
                Text("Select Driver")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("AVAILABLE DRIVERS")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                if driverManager.isLoading {
                    ProgressView("Loading available drivers...")
                        .padding()
                } else if driverManager.availableDrivers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "car")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Available Drivers")
                            .font(.headline)
                        
                        Text("There are currently no drivers available. Please try again later.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            
                        Button(action: {
                            driverManager.loadAvailableDrivers()
                        }) {
                            Text("Refresh Drivers")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: 200)
                                .padding()
                                .background(Color(hex: "F4A261"))
                                .cornerRadius(12)
                        }
                        .padding()
                    }
                    .padding()
                } else {
                    List {
                        ForEach(driverManager.availableDrivers) { driver in
                            Button(action: {
                                selectedDriverId = driver.id
                            }) {
                                HStack {
                                    // Only show driver name
                                    Text(driver.name)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    if selectedDriverId == driver.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Button(action: {
                        if let driverId = selectedDriverId,
                           let driver = driverManager.availableDrivers.first(where: { $0.id == driverId }) {
                            assignDriver(driver)
                        } else {
                            alertMessage = "Please select a driver first"
                            showingAlert = true
                        }
                    }) {
                        Text("Assign Selected Driver")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedDriverId == nil ? Color.gray : Color(hex: "F4A261"))
                            .cornerRadius(12)
                    }
                    .disabled(selectedDriverId == nil)
                    .padding()
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }, 
                trailing: Button("Refresh") {
                    driverManager.loadAvailableDrivers()
                }
            )
        }
        .onAppear {
            // Ensure fresh data is loaded every time the sheet appears
            print("DriverAssignmentSheet appeared - loading fresh driver data")
            driverManager.loadAvailableDrivers()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Driver Assignment"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("successfully") {
                        isPresented = false
                    }
                }
            )
        }
    }
    
    private func assignDriver(_ driver: DriverModel) {
        driverManager.assignDriver(driverId: driver.id, orderId: order.id) { success in
            if success {
                // Update order status in Firebase
                let db = Database.database().reference()
                // Set status to "in_progress" and order_status to "assigned_driver"
                let updates: [String: Any] = [
                    "status": "in_progress",
                    "order_status": "assigned_driver",
                    "driverId": driver.id,
                    "driverName": driver.name,
                    "driverPhone": driver.phone,
                    "updatedAt": ServerValue.timestamp()
                ]
                
                print("Updating order with: \(updates)")
                
                db.child("orders").child(order.id).updateChildValues(updates) { error, _ in
                    if let error = error {
                        alertMessage = "Error updating order: \(error.localizedDescription)"
                        print("Firebase error: \(error.localizedDescription)")
                    } else {
                        alertMessage = "Driver assigned successfully!"
                        print("Order \(order.id) updated successfully")
                        
                        // Verify the update
                        db.child("orders").child(order.id).observeSingleEvent(of: .value) { snapshot in
                            if let data = snapshot.value as? [String: Any] {
                                print("Updated order data: status=\(data["status"] ?? "nil"), order_status=\(data["order_status"] ?? "nil")")
                            }
                        }
                    }
                    showingAlert = true
                }
            } else {
                alertMessage = driverManager.error ?? "Failed to assign driver"
                showingAlert = true
            }
        }
    }
}

struct DriverAssignmentRow: View {
    let driver: DriverModel
    let onAssign: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.headline)
                
                Text(driver.phone)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", driver.rating))
                    Text("(\(driver.totalDeliveries) deliveries)")
                        .foregroundColor(.gray)
                }
                .font(.caption)
            }
            
            Spacer()
            
            Button(action: onAssign) {
                Text("Assign")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "F4A261"))
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 8)
    }
}

