import SwiftUI
import FirebaseDatabase

struct AdminDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var unreadMessageCount: Int = 0
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Support Management")) {
                    NavigationLink(destination: AdminChatListView(authViewModel: authViewModel)) {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(Color(hex: "F4A261"))
                            Text("Customer Support Messages")
                            
                            Spacer()
                            
                            if unreadMessageCount > 0 {
                                Text("\(unreadMessageCount)")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color(hex: "F4A261"))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                
                Section(header: Text("User Management")) {
                    NavigationLink(destination: Text("Customer Management")) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(Color(hex: "F4A261"))
                            Text("Manage Customers")
                        }
                    }
                    
                    NavigationLink(destination: Text("Restaurant Management")) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(Color(hex: "F4A261"))
                            Text("Manage Restaurants")
                        }
                    }
                    
                    NavigationLink(destination: Text("Driver Management")) {
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(Color(hex: "F4A261"))
                            Text("Manage Drivers")
                        }
                    }
                }
                
                Section(header: Text("System")) {
                    NavigationLink(destination: Text("App Settings")) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(Color(hex: "F4A261"))
                            Text("App Settings")
                        }
                    }
                    
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Admin Dashboard")
            .onAppear {
                loadUnreadMessageCount()
            }
        }
    }
    
    private func loadUnreadMessageCount() {
        let db = Database.database().reference()
        db.child("chat_management").child("threads").observeSingleEvent(of: .value) { snapshot in
            var count = 0
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let dict = snapshot.value as? [String: Any],
                      let unreadCount = dict["unreadCount"] as? Int else { continue }
                
                count += unreadCount
            }
            
            DispatchQueue.main.async {
                self.unreadMessageCount = count
            }
        }
    }
}

struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = AuthViewModel()
        viewModel.currentUserRole = .admin
        return AdminDashboardView(authViewModel: viewModel)
    }
} 