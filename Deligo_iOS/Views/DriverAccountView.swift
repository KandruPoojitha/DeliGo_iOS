import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct DriverAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var isEditingProfile = false
    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = true
    private var databaseRef: DatabaseReference = Database.database().reference()
    
    // Add explicit public initializer
    public init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading profile...")
                            Spacer()
                        }
                    }
                } else {
                    // Profile Section
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(fullName)
                                    .font(.headline)
                                Text(email)
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                Text(phone)
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                isEditingProfile = true
                            }) {
                                Text("Edit")
                                    .foregroundColor(Color(hex: "F4A261"))
                            }
                        }
                    }
                    
                    // Driver Specific Sections
                    Section(header: Text("Driver Account")) {
                        NavigationLink("Vehicle Information") {
                            Text("Vehicle Information View")
                        }
                        
                        NavigationLink("Delivery Preferences") {
                            Text("Delivery Preferences View")
                        }
                    }
                    
                    Section(header: Text("Earnings")) {
                        NavigationLink(destination: DriverTipHistoryView(authViewModel: authViewModel)) {
                            Label("Tip History", systemImage: "dollarsign.circle")
                        }
                        
                        NavigationLink(destination: DriverEarningsHistoryView(authViewModel: authViewModel)) {
                            Label("Earnings History", systemImage: "chart.bar")
                        }
                        
                        NavigationLink("Bank Details") {
                            Text("Bank Details View")
                        }
                    }
                    
                    // Support
                    Section(header: Text("Support")) {
                        NavigationLink(destination: DriverChatView(authViewModel: authViewModel)) {
                            Label("Contact Support", systemImage: "message")
                        }
                        
                        NavigationLink("Help Center") {
                            Text("Help Center View")
                        }
                    }
                    
                    // Logout Button
                    Section {
                        Button(action: {
                            authViewModel.logout()
                        }) {
                            HStack {
                                Spacer()
                                Text("Logout")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .sheet(isPresented: $isEditingProfile) {
                DriverEditProfileView(
                    authViewModel: authViewModel,
                    fullName: $fullName,
                    phone: $phone,
                    onSuccess: {
                        isEditingProfile = false
                        showingAlert = true
                        alertMessage = "Profile updated successfully!"
                    },
                    onError: { error in
                        isEditingProfile = false
                        showingAlert = true
                        alertMessage = "Error updating profile: \(error)"
                    }
                )
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                setupRealtimeProfileUpdates()
            }
            .onDisappear {
                // Remove observers when the view disappears
                removeProfileObservers()
            }
        }
    }
    
    private func setupRealtimeProfileUpdates() {
        guard let driverId = authViewModel.currentUserId else {
            isLoading = false
            return
        }
        
        isLoading = true
        print("DEBUG: Setting up real-time profile updates for driver ID: \(driverId)")
        
        // Set up real-time listener for driver data
        let driversRef = databaseRef.child("drivers").child(driverId)
        driversRef.observe(.value) { snapshot, _ in
            if snapshot.exists(), let value = snapshot.value as? [String: Any] {
                print("DEBUG: Real-time update received from drivers path")
                
                DispatchQueue.main.async {
                    // Extract driver data
                    self.fullName = value["fullName"] as? String ?? value["name"] as? String ?? ""
                    self.phone = value["phone"] as? String ?? ""
                    self.email = value["email"] as? String ?? ""
                    
                    // If email is still empty, try to get it from Auth
                    if self.email.isEmpty, let user = Auth.auth().currentUser {
                        self.email = user.email ?? ""
                    }
                    
                    // If name is still empty, try to get it from hours.name or other possible locations
                    if self.fullName.isEmpty {
                        if let hours = value["hours"] as? [String: Any],
                           let name = hours["name"] as? String {
                            self.fullName = name
                        } else if let userInfo = value["user_info"] as? [String: Any],
                                  let name = userInfo["fullName"] as? String {
                            self.fullName = name
                        }
                    }
                    
                    // If phone is still empty, try other possible locations
                    if self.phone.isEmpty {
                        if let phone = value["phoneNumber"] as? String {
                            self.phone = phone
                        } else if let userInfo = value["user_info"] as? [String: Any],
                                  let phone = userInfo["phone"] as? String {
                            self.phone = phone
                        }
                    }
                    
                    self.isLoading = false
                }
            } else {
                print("DEBUG: No driver data found in Firebase")
                
                // Fallback to users collection
                let usersRef = self.databaseRef.child("users").child(driverId)
                usersRef.observe(.value) { userSnapshot, _ in
                    DispatchQueue.main.async {
                        if userSnapshot.exists(), let userData = userSnapshot.value as? [String: Any] {
                            print("DEBUG: Found driver data in users collection")
                            
                            self.fullName = userData["fullName"] as? String ?? ""
                            self.phone = userData["phone"] as? String ?? ""
                            self.email = userData["email"] as? String ?? ""
                        }
                        
                        // If still no data, try to get basic info from Auth
                        if self.fullName.isEmpty || self.email.isEmpty {
                            if let user = Auth.auth().currentUser {
                                self.email = user.email ?? ""
                                self.fullName = user.displayName ?? ""
                            }
                        }
                        
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func removeProfileObservers() {
        guard let driverId = authViewModel.currentUserId else { return }
        
        print("DEBUG: Removing Firebase observers for driver profile")
        databaseRef.child("drivers").child(driverId).removeAllObservers()
        databaseRef.child("users").child(driverId).removeAllObservers()
    }
}

struct DriverEditProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var fullName: String
    @Binding var phone: String
    @State private var localName: String = ""
    @State private var localPhone: String = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    var onError: (String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Driver Information")) {
                    TextField("Full Name", text: $localName)
                    TextField("Phone Number", text: $localPhone)
                        .keyboardType(.phonePad)
                }
                
                Section {
                    Button(action: updateProfile) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(Color(hex: "F4A261"))
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .onAppear {
                localName = fullName
                localPhone = phone
            }
        }
    }
    
    private func updateProfile() {
        guard let driverId = authViewModel.currentUserId else { return }
        isLoading = true
        
        let database = Database.database().reference()
        let updates: [String: Any] = [
            "fullName": localName.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": localPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        print("DEBUG: Starting driver profile update for user: \(driverId)")
        
        // Update in both drivers and users collections to ensure consistency
        let driversRef = database.child("drivers").child(driverId)
        let usersRef = database.child("users").child(driverId)
        
        // First update in the drivers collection
        driversRef.updateChildValues(updates) { error, _ in
            if let error = error {
                print("DEBUG: Error updating driver data: \(error.localizedDescription)")
                // Don't call onError yet, still try users collection
            } else {
                print("DEBUG: Successfully updated driver data")
            }
            
            // Also update in users collection to maintain data consistency
            usersRef.updateChildValues(updates) { error, _ in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("DEBUG: Error updating user data: \(error.localizedDescription)")
                        self.onError(error.localizedDescription)
                    } else {
                        print("DEBUG: Successfully updated user data")
                        // Manually update the UI values
                        self.fullName = self.localName
                        self.phone = self.localPhone
                        self.onSuccess()
                    }
                }
            }
        }
    }
}

