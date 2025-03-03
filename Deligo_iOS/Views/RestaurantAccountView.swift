import SwiftUI
import FirebaseDatabase

struct RestaurantAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showEditProfile = false
    @State private var showBusinessHours = false
    @State private var showNotifications = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Profile Section
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "F4A261"))
                    
                    // User Info
                    Text(authViewModel.fullName ?? "Restaurant Owner")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(authViewModel.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                // Settings List
                VStack(spacing: 1) {
                    // Profile Settings Button
                    Button(action: {
                        showEditProfile = true
                    }) {
                        SettingsRow(icon: "person.fill", title: "Profile Settings")
                    }
                    
                    // Business Hours Button
                    Button(action: {
                        showBusinessHours = true
                    }) {
                        SettingsRow(icon: "clock.fill", title: "Business Hours")
                    }
              
                    // Support Button
                    Button(action: {
                        // Handle support
                    }) {
                        SettingsRow(icon: "questionmark.circle.fill", title: "Support")
                    }
                    
                    // Terms & Privacy Button
                    Button(action: {
                        // Handle terms
                    }) {
                        SettingsRow(icon: "doc.text.fill", title: "Terms & Privacy")
                    }
                }
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Version Info
                Text("Version 1.0.0")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Logout Button
                Button(action: {
                    authViewModel.logout()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Logout")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "F4A261"))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(authViewModel: authViewModel)
        }
        .sheet(isPresented: $showBusinessHours) {
            BusinessHoursView()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationSettingsView()
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
        }
        .foregroundColor(.primary)
        .padding()
        .background(Color.white)
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authViewModel: AuthViewModel
    @State private var fullName = ""
    @State private var phone = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Full Name", text: $fullName)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save profile changes
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BusinessHoursView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var openingTime = Date()
    @State private var closingTime = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Business Hours")) {
                    DatePicker("Opening Time",
                             selection: $openingTime,
                             displayedComponents: .hourAndMinute)
                    
                    DatePicker("Closing Time",
                             selection: $closingTime,
                             displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Business Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save business hours
                        dismiss()
                    }
                }
            }
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newOrders = true
    @State private var orderUpdates = true
    @State private var messages = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Push Notifications")) {
                    Toggle("New Orders", isOn: $newOrders)
                    Toggle("Order Updates", isOn: $orderUpdates)
                    Toggle("Messages", isOn: $messages)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RestaurantAccountView(authViewModel: AuthViewModel())
}
