import SwiftUI

struct ChatManagementView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var chatManager: ChatManager
    @State private var customerUnreadCount: Int = 0
    @State private var restaurantUnreadCount: Int = 0
    @State private var driverUnreadCount: Int = 0
    @State private var isLoading: Bool = true
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        
        // Create a chat manager for the admin
        let userId = authViewModel.currentUserId ?? ""
        let userName = "Admin Support" // Fixed name for admin
        
        _chatManager = StateObject(wrappedValue: ChatManager(
            userId: userId,
            userName: userName,
            isAdmin: true
        ))
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading unread counts...")
            } else {
                List {
                    Section(header: Text("Support Channels")) {
                        NavigationLink(destination: AdminChatListView(authViewModel: authViewModel, supportType: .customer)) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color(hex: "F4A261"))
                                Text("Customer Support")
                                
                                Spacer()
                                
                                if customerUnreadCount > 0 {
                                    Text("\(customerUnreadCount)")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color(hex: "F4A261"))
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        
                        NavigationLink(destination: AdminChatListView(authViewModel: authViewModel, supportType: .restaurant)) {
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(Color(hex: "F4A261"))
                                Text("Restaurant Support")
                                
                                Spacer()
                                
                                if restaurantUnreadCount > 0 {
                                    Text("\(restaurantUnreadCount)")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color(hex: "F4A261"))
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        
                        NavigationLink(destination: AdminChatListView(authViewModel: authViewModel, supportType: .driver)) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundColor(Color(hex: "F4A261"))
                                Text("Driver Support")
                                
                                Spacer()
                                
                                if driverUnreadCount > 0 {
                                    Text("\(driverUnreadCount)")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color(hex: "F4A261"))
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Chat Management")
        .onAppear {
            loadUnreadCounts()
        }
    }
    
    private func loadUnreadCounts() {
        isLoading = true
        
        // Load customer unread count
        chatManager.getUnreadCountByRole(role: "Customer") { count in
            DispatchQueue.main.async {
                self.customerUnreadCount = count
            }
        }
        
        // Load restaurant unread count
        chatManager.getUnreadCountByRole(role: "Restaurant") { count in
            DispatchQueue.main.async {
                self.restaurantUnreadCount = count
            }
        }
        
        // Load driver unread count
        chatManager.getUnreadCountByRole(role: "Driver") { count in
            DispatchQueue.main.async {
                self.driverUnreadCount = count
                self.isLoading = false // Set loading to false after all counts are loaded
            }
        }
    }
}

struct ChatManagementView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatManagementView(authViewModel: AuthViewModel())
        }
    }
} 