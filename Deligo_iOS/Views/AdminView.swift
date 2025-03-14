import SwiftUI
import FirebaseAuth

struct AdminView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: AdminTab? = nil
    
    enum AdminTab {
        case userManagement
        case chatManagement
    }
    
    var body: some View {
        VStack(spacing: 20) {
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
                    AdminMenuButton(title: "Chat Management")
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Logout Button
            Button(action: handleLogout) {
                Text("Logout")
                    .fontWeight(.medium)
                    .foregroundColor(.red)
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

