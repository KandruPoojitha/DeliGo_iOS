import SwiftUI
import FirebaseAuth

struct AdminView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: AdminTab? = nil
    @State private var totalUnreadCount: Int = 0
    @StateObject private var chatManager: ChatManager
    
    enum AdminTab: Identifiable {
        case userManagement
        case chatManagement
        case otherActivities
        
        var id: Self { self }
    }
    
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
        VStack {
            Image("deligo_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .padding(.top, 30)
            
            // Welcome Text
            Text("Welcome, Admin!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Admin Dashboard")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer().frame(height: 20)
            
            // Admin Actions
            VStack(spacing: 15) {
                Button(action: { selectedTab = .userManagement }) {
                    AdminMenuButton(title: "User Management")
                }
                
                Button(action: { selectedTab = .chatManagement }) {
                    ZStack(alignment: .topTrailing) {
                        AdminMenuButton(title: "Chat Management")
                        
                        if totalUnreadCount > 0 {
                            Text("\(totalUnreadCount)")
                                .font(.caption)
                                .padding(6)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .offset(x: -5, y: -5)
                        }
                    }
                }
                
                Button(action: { selectedTab = .otherActivities }) {
                    AdminMenuButton(title: "Other Activities")
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: handleLogout) {
                Text("Logout")
                    .foregroundColor(.red)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 30)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
        .sheet(item: $selectedTab) { tab in
            switch tab {
            case .userManagement:
                NavigationView {
                    UserManagementView()
                }
            case .chatManagement:
                NavigationView {
                    ChatManagementView(authViewModel: authViewModel)
                }
            case .otherActivities:
                NavigationView {
                    OtherActivitiesView(authViewModel: authViewModel)
                }
            }
        }
        .onAppear {
            loadTotalUnreadCount()
        }
    }
    
    private func handleLogout() {
        authViewModel.logout()
    }
    
    private func loadTotalUnreadCount() {
        chatManager.getTotalUnreadCount { count in
            DispatchQueue.main.async {
                self.totalUnreadCount = count
            }
        }
    }
}

struct OtherActivitiesView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showOrderManagement = false
    @State private var showPaymentTransactions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo
                Image("deligo_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .padding(.top, 40)
                
                Text("Other Activities")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                
                // Activity Buttons
                VStack(spacing: 15) {
                    NavigationLink(destination: AdminOrderManagementView(), isActive: $showOrderManagement) {
                        EmptyView()
                    }
                    
                    Button(action: {
                        showOrderManagement = true
                    }) {
                        Text("Order Management")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "F4A261"))
                            .cornerRadius(25)
                    }
                    
                    Button(action: {
                        showPaymentTransactions = true
                    }) {
                        Text("View Payment Transactions")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "F4A261"))
                            .cornerRadius(25)
                    }
                    
                    NavigationLink(destination: PaymentTransactionsView(), isActive: $showPaymentTransactions) {
                        EmptyView()
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            .background(Color(.systemGray6))
        }
    }
}

// Custom Admin Button UI
struct AdminMenuButton: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "F4A261"))
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}

#Preview {
    AdminView(authViewModel: AuthViewModel())
}


