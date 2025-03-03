import SwiftUI
import FirebaseDatabase

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                switch authViewModel.currentUserRole {
                case .customer:
                    CustomerHomeView()
                case .restaurant:
                    RestaurantHomeView(authViewModel: authViewModel)
                case .driver:
                    DriverHomeView()
                case .admin:
                    AdminView(authViewModel: authViewModel)
                case .none:
                    // Show error or return to login
                    Text("No role assigned")
                        .onAppear {
                            authViewModel.logout()
                        }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        Text("Logout")
                            .foregroundColor(Color(hex: "F4A261"))
                    }
                }
            }
        }
    }
}

struct DashboardButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "F4A261"))
            Text(title)
                .font(.title3)
                .fontWeight(.medium)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct UserManagementView: View {
    @StateObject private var viewModel = UserManagementViewModel()
    @State private var selectedRole: UserRole?
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("User Management")
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top)
            
            // Category Buttons in a row
            HStack(spacing: 12) {
                ForEach([UserRole.customer, UserRole.driver, UserRole.restaurant], id: \.self) { role in
                    Button(action: {
                        selectedRole = role
                        viewModel.fetchUsers(for: role)
                    }) {
                        Text(role.rawValue)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedRole == role ?
                                Color(hex: "F4A261") :
                                Color(hex: "F4A261").opacity(0.7)
                            )
                            .cornerRadius(25)
                    }
                }
            }
            .padding(.horizontal)
            
            // Selected category title
            if let selectedRole = selectedRole {
                Text(selectedRole.rawValue + "s")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            
            // User list
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading users...")
                Spacer()
            } else {
                if viewModel.users.isEmpty && selectedRole != nil {
                    Spacer()
                    Text("No users found")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.users) { user in
                                UserCard(user: user)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

struct UserCard: View {
    let user: UserData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name row
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(Color(hex: "F4A261"))
                    .font(.system(size: 36))
                
                Text("Name: \(user.fullName)")
                    .font(.headline)
            }
            
            // Email row
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text("Email: \(user.email)")
                    .font(.subheadline)
            }
            
            // Phone row
            HStack {
                Image(systemName: "phone.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text("Phone: \(user.phone)")
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct UserData: Identifiable {
    let id: String
    let fullName: String
    let email: String
    let phone: String
    let role: UserRole
}

class UserManagementViewModel: ObservableObject {
    @Published var users: [UserData] = []
    @Published var isLoading = false
    private let db = Database.database().reference()
    
    func fetchUsers(for role: UserRole) {
        isLoading = true
        users.removeAll()
        
        let rolePath = "\(role.rawValue.lowercased())s"
        print("Fetching users from path: \(rolePath)")
        
        db.child(rolePath).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var fetchedUsers: [UserData] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let userData = snapshot.value as? [String: Any] else {
                    continue
                }
                
                let fullName = userData["fullName"] as? String ?? "No Name"
                let email = userData["email"] as? String ?? "No Email"
                let phone = userData["phone"] as? String ?? "No Phone"
                
                let user = UserData(
                    id: snapshot.key,
                    fullName: fullName,
                    email: email,
                    phone: phone,
                    role: role
                )
                fetchedUsers.append(user)
            }
            
            DispatchQueue.main.async {
                self.users = fetchedUsers
                self.isLoading = false
                print("Fetched \(fetchedUsers.count) users for role: \(role.rawValue)")
            }
        }
    }
}

struct ChatManagementView: View {
    var body: some View {
        Text("Chat Management")
            .navigationTitle("Chat Management")
    }
}

struct CustomerHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome Customer")
                .font(.title)
                .padding()
        }
    }
}

struct RestaurantHomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            switch authViewModel.documentStatus {
            case .notSubmitted:
                DocumentUploadView(authViewModel: authViewModel)
            case .pending:
                VStack(spacing: 20) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "F4A261"))
                    
                    Text("Documents Under Review")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your documents are being reviewed by our team. This process usually takes 1-2 business days.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                .padding()
            case .rejected:
                VStack(spacing: 20) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Documents Rejected")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your documents were rejected. Please submit new documents.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Button(action: {
                        authViewModel.documentStatus = .notSubmitted
                    }) {
                        Text("Submit New Documents")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "F4A261"))
                            .cornerRadius(12)
                    }
                }
                .padding()
            case .approved:
                VStack {
                    Text("Welcome Restaurant")
                        .font(.title)
                        .padding()
                    
                    // Add restaurant dashboard content here
                }
            }
        }
    }
}

struct DriverHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome Driver")
                .font(.title)
                .padding()
        }
    }
}

#Preview {
    HomeView(authViewModel: AuthViewModel())
} 
