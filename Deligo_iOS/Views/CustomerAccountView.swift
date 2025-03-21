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
                loadUserProfile()
                
                // Listen for logout notification
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("UserDidLogout"),
                    object: nil,
                    queue: .main
                ) { _ in
                    print("DEBUG: CustomerAccountView received logout notification")
                    navigateToLogin = true
                }
            }
        }
    }
    
    private func loadUserProfile() {
        isLoading = true
        guard let userId = authViewModel.currentUserId else {
            isLoading = false
            return
        }
        
        let database = Database.database().reference()
        
        // Try to load from the customers path as shown in the Firebase screenshot
        database.child("customers").child(userId).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists(), let value = snapshot.value as? [String: Any] {
                print("DEBUG: Found user data in customers path")
                
                // Extract user data from the customer record
                self.fullName = value["fullName"] as? String ?? ""
                self.phone = value["phone"] as? String ?? ""
                self.email = value["email"] as? String ?? ""
                
                // If email is still empty, try to get it from Auth
                if self.email.isEmpty, let user = Auth.auth().currentUser {
                    self.email = user.email ?? ""
                }
                
                self.isLoading = false
            } else {
                print("DEBUG: No user data found in customers path, trying users path as fallback")
                
                // Fallback to the users path if no data found in customers
                database.child("users").child(userId).observeSingleEvent(of: .value) { snapshot in
                    guard let value = snapshot.value as? [String: Any] else {
                        print("DEBUG: No user data found in users path either")
                        self.isLoading = false
                        return
                    }
                    
                    print("DEBUG: Found user data in users path")
                    self.fullName = value["fullName"] as? String ?? ""
                    self.phone = value["phone"] as? String ?? ""
                    self.email = value["email"] as? String ?? ""
                    
                    // If email is still empty, try to get it from Auth
                    if self.email.isEmpty, let user = Auth.auth().currentUser {
                        self.email = user.email ?? ""
                    }
                    
                    self.isLoading = false
                }
            }
        }
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
        
        // First, check if user exists in the customers path
        database.child("customers").child(userId).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                print("DEBUG: Updating user data in customers path")
                // Update in customers path
                database.child("customers").child(userId).updateChildValues(updates) { error, _ in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            print("DEBUG: Error updating customer data: \(error.localizedDescription)")
                            self.onError(error.localizedDescription)
                        } else {
                            print("DEBUG: Successfully updated customer data")
                            self.fullName = self.localName
                            self.phone = self.localPhone
                            self.onSuccess()
                        }
                    }
                }
            } else {
                print("DEBUG: User not found in customers path, trying users path")
                // Update in users path as fallback
                database.child("users").child(userId).updateChildValues(updates) { error, _ in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            print("DEBUG: Error updating user data: \(error.localizedDescription)")
                            self.onError(error.localizedDescription)
                        } else {
                            print("DEBUG: Successfully updated user data")
                            self.fullName = self.localName
                            self.phone = self.localPhone
                            self.onSuccess()
                        }
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

