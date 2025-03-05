import SwiftUI
import FirebaseDatabase

struct AdminView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: AdminTab? = nil
    
    enum AdminTab {
        case userManagement
        case chatManagement
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Admin Dashboard")
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
            
            // Main Content
            ScrollView {
                VStack(spacing: 20) {
                    // User Management Card
                    Button(action: { selectedTab = .userManagement }) {
                        AdminMenuCard(
                            icon: "person.2.fill",
                            title: "User Management",
                            description: "Manage all users and their roles"
                        )
                    }
                    
                    // Chat Management Card
                    Button(action: { selectedTab = .chatManagement }) {
                        AdminMenuCard(
                            icon: "message.fill",
                            title: "Chat Management",
                            description: "Monitor and manage chat communications"
                        )
                    }
                }
                .padding()
            }
            
            Spacer()
            
            Button(action: handleLogout) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.white)
                    Text("Logout")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("F4A261"))
                .cornerRadius(25)
            }
            .padding()
        }
        .background(Color(.systemGray6))
        .sheet(item: $selectedTab) { tab in
            switch tab {
            case .userManagement:
                NavigationView {
                    UserManagementView()
                }
            case .chatManagement:
                NavigationView {
                    ChatManagementView()
                }
            }
        }
    }
    
    private func handleLogout() {
        authViewModel.logout()
    }
}

extension AdminView.AdminTab: Identifiable {
    var id: Self { self }
}

struct AdminMenuCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(Color("F4A261"))
                .frame(width: 60, height: 60)
                .background(Color("F4A261").opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    AdminView(authViewModel: AuthViewModel())
} 
