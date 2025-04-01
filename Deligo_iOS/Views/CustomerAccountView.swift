import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct CustomerAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var isEditingProfile = false
    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = true
    @State private var navigateToLogin = false
    private var databaseRef: DatabaseReference = Database.database().reference()
    
    // Add explicit initializer to fix accessibility
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
                    
                    // Support
                    Section(header: Text("Support")) {
                        NavigationLink(destination: CustomerChatView(authViewModel: authViewModel)) {
                            Label("Contact Support", systemImage: "message")
                        }
                        
                        NavigationLink(destination: FAQView()) {
                            Label("FAQ", systemImage: "questionmark.circle")
                        }
                    }
                    
                    // Logout Button
                    Section {
                        Button(action: {
                            print("DEBUG: Customer logging out")
                            authViewModel.logout()
                            navigateToLogin = true
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
                EditProfileView(
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
                // Remove observers when view disappears
                removeProfileObservers()
            }
            .fullScreenCover(isPresented: $navigateToLogin) {
                LoginView()
            }
        }
    }
    
    private func setupRealtimeProfileUpdates() {
        guard let userId = authViewModel.currentUserId else {
            isLoading = false
            return
        }
        
        isLoading = true
        print("DEBUG: Setting up real-time profile updates for user ID: \(userId)")
        
        // First try to observe the customers path
        let customerRef = databaseRef.child("customers").child(userId)
        customerRef.observe(.value) { snapshot, _ in
            if snapshot.exists(), let value = snapshot.value as? [String: Any] {
                print("DEBUG: Real-time update received from customers path")
                
                DispatchQueue.main.async {
                    // Extract user data from the customer record
                    self.fullName = value["fullName"] as? String ?? ""
                    self.phone = value["phone"] as? String ?? ""
                    self.email = value["email"] as? String ?? ""
                    
                    // If email is still empty, try to get it from Auth
                    if self.email.isEmpty, let user = Auth.auth().currentUser {
                        self.email = user.email ?? ""
                    }
                    
                    self.isLoading = false
                }
            } else {
                print("DEBUG: No data found in customers path, trying users path")
                
                // If no data in customers, try the users path as fallback
                let userRef = self.databaseRef.child("users").child(userId)
                userRef.observe(.value) { userSnapshot, _ in
                    DispatchQueue.main.async {
                        if userSnapshot.exists(), let userData = userSnapshot.value as? [String: Any] {
                            print("DEBUG: Real-time update received from users path")
                            
                            self.fullName = userData["fullName"] as? String ?? ""
                            self.phone = userData["phone"] as? String ?? ""
                            self.email = userData["email"] as? String ?? ""
                            
                            // If email is still empty, try to get it from Auth
                            if self.email.isEmpty, let user = Auth.auth().currentUser {
                                self.email = user.email ?? ""
                            }
                        } else {
                            print("DEBUG: No user data found in either path")
                            // Try to at least get the email from Auth
                            if let user = Auth.auth().currentUser {
                                self.email = user.email ?? ""
                            }
                        }
                        
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func removeProfileObservers() {
        guard let userId = authViewModel.currentUserId else { return }
        
        print("DEBUG: Removing Firebase observers")
        databaseRef.child("customers").child(userId).removeAllObservers()
        databaseRef.child("users").child(userId).removeAllObservers()
    }
}

struct EditProfileView: View {
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
                Section(header: Text("Profile Information")) {
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
        guard let userId = authViewModel.currentUserId else { return }
        isLoading = true
        
        let database = Database.database().reference()
        let updates: [String: Any] = [
            "fullName": localName.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": localPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        print("DEBUG: Starting profile update for user: \(userId)")
        
        // Update in both locations to ensure consistency
        let customersRef = database.child("customers").child(userId)
        let usersRef = database.child("users").child(userId)
        
        // First update in the customers collection
        customersRef.updateChildValues(updates) { error, _ in
            if let error = error {
                print("DEBUG: Error updating customer data: \(error.localizedDescription)")
                // Don't call onError yet, still try users collection
            } else {
                print("DEBUG: Successfully updated customer data")
                // Continue to update users collection as well
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
                        // Also manually update the UI immediately
                        self.fullName = self.localName
                        self.phone = self.localPhone
                        self.onSuccess()
                    }
                }
            }
        }
    }
}

struct FAQView: View {
    var body: some View {
        Text("FAQ View")
            .navigationTitle("FAQ")
    }
}

