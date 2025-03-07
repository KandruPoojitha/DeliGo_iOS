import SwiftUI
import FirebaseDatabase

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var userRole: String?
    @State private var documentStatus: String?
    
    var body: some View {
        Group {
            if let role = userRole {
                switch role {
                case "Restaurant":
                    if documentStatus == "approved" {
                        RestaurantHomeView(authViewModel: authViewModel)
                    } else {
                        RestaurantDocumentsView(authViewModel: authViewModel)
                    }
                case "Driver":
                    if documentStatus == "approved" {
                        DriverHomeView(authViewModel: authViewModel)
                    } else {
                        DriverDocumentsView(authViewModel: authViewModel)
                    }
                case "Admin":
                    AdminDashboardView(authViewModel: authViewModel)
                default:
                    MainCustomerView(authViewModel: authViewModel)
                }
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        checkUserRole()
                    }
            }
        }
    }
    
    private func checkUserRole() {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        // First check in admins
        db.child("admins").child(userId).child("role").observeSingleEvent(of: .value) { snapshot in
            if let role = snapshot.value as? String {
                print("DEBUG: Found user role in admins: \(role)")
                self.userRole = role
                return
            }
            
            // If not found in admins, check in restaurants
            db.child("restaurants").child(userId).observeSingleEvent(of: .value) { snapshot in
                if let userData = snapshot.value as? [String: Any],
                   let role = userData["role"] as? String {
                    print("DEBUG: Found user role in restaurants: \(role)")
                    self.userRole = role
                    
                    // Check restaurant document status
                    if let documents = userData["documents"] as? [String: Any],
                       let status = documents["status"] as? String {
                        self.documentStatus = status
                    } else {
                        self.documentStatus = "not_submitted"
                    }
                    return
                }
                
                // If not found in restaurants, check in drivers
                db.child("drivers").child(userId).observeSingleEvent(of: .value) { snapshot in
                    if let userData = snapshot.value as? [String: Any],
                       let role = userData["role"] as? String {
                        print("DEBUG: Found user role in drivers: \(role)")
                        self.userRole = role
                        
                        // Check driver document status
                        if let documents = userData["documents"] as? [String: Any],
                           let status = documents["status"] as? String {
                            self.documentStatus = status
                        } else {
                            self.documentStatus = "not_submitted"
                        }
                        return
                    }
                    
                    // If not found anywhere, default to Customer
                    print("DEBUG: User role not found, defaulting to Customer")
                    self.userRole = "Customer"
                    self.documentStatus = nil
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
    @State var user: UserData
    @State private var showDetailView = false
    
    var body: some View {
        Button(action: {
            if user.role == .restaurant {
                showDetailView = true
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Name row
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(Color(hex: "F4A261"))
                        .font(.system(size: 36))
                    
                    Text(user.fullName)
                        .font(.headline)
                }
                
                // Email row
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                        .frame(width: 20)
                    Text(user.email)
                        .font(.subheadline)
                }
                
                // Phone row
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                        .frame(width: 20)
                    Text(user.phone)
                        .font(.subheadline)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetailView) {
            if user.role == .restaurant {
                RestaurantDetailView(user: $user)
            }
        }
    }
}

struct RestaurantDetailView: View {
    @Binding var user: UserData
    @StateObject private var viewModel = UserManagementViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDocumentPreview = false
    @State private var selectedImageURL: String?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Information Section
                    GroupBox(label: Text("Basic Information").bold()) {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(icon: "person.fill", title: "Name", value: user.fullName)
                            DetailRow(icon: "envelope.fill", title: "Email", value: user.email)
                            DetailRow(icon: "phone.fill", title: "Phone", value: user.phone)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Document Status Section
                    GroupBox(label: Text("Document Status").bold()) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Status:")
                                Text(user.documentStatus?.capitalized ?? "Not Submitted")
                                    .foregroundColor(statusColor(for: user.documentStatus))
                                    .fontWeight(.medium)
                            }
                            
                            if let hours = user.businessHours {
                                Divider()
                                Text("Business Hours")
                                    .fontWeight(.medium)
                                Text("Opening: \(hours.opening)")
                                Text("Closing: \(hours.closing)")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Documents Section
                    GroupBox(label: Text("Documents").bold()) {
                        VStack(alignment: .leading, spacing: 16) {
                            if let restaurantProofURL = user.restaurantProofURL {
                                Button(action: {
                                    selectedImageURL = restaurantProofURL
                                    showDocumentPreview = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                        Text("View Restaurant License")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            if let ownerIDURL = user.ownerIDURL {
                                Button(action: {
                                    selectedImageURL = ownerIDURL
                                    showDocumentPreview = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                        Text("View Owner's ID")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Approval/Rejection Section
                    if user.documentStatus?.lowercased() == "pending_review" {
                        GroupBox(label: Text("Actions").bold()) {
                            HStack(spacing: 16) {
                                Button(action: {
                                    updateStatus("approved")
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Approve")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    updateStatus("rejected")
                                }) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Reject")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Restaurant Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentPreview) {
            if let url = selectedImageURL {
                DocumentPreviewView(imageURL: url)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func statusColor(for status: String?) -> Color {
        guard let status = status?.lowercased() else { return .gray }
        switch status {
        case "approved":
            return .green
        case "rejected":
            return .red
        case "pending_review":
            return .orange
        default:
            return .gray
        }
    }
    
    private func updateStatus(_ status: String) {
        viewModel.updateDocumentStatus(userId: user.id, status: status) { error in
            if let error = error {
                errorMessage = "Failed to update status: \(error.localizedDescription)"
                showError = true
            } else {
                // Update the user data locally
                user.documentStatus = status
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            Text(title + ":")
                .foregroundColor(.gray)
            Text(value)
        }
    }
}

struct DocumentPreviewView: View {
    let imageURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if let error = error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error loading image: \(error.localizedDescription)")
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if let image = image {
                    ScrollView {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                }
            }
            .navigationTitle("Document Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = URL(string: imageURL) else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let data = data, let loadedImage = UIImage(data: data) else {
                    self.error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
                    return
                }
                
                self.image = loadedImage
            }
        }.resume()
    }
}

struct UserData: Identifiable {
    let id: String
    let fullName: String
    let email: String
    let phone: String
    let role: UserRole
    // Document related fields
    var documentStatus: String?
    var restaurantProofURL: String?
    var ownerIDURL: String?
    var businessHours: BusinessHours?
}

struct BusinessHours: Codable {
    let opening: String
    let closing: String
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
                
                var documentStatus: String?
                var restaurantProofURL: String?
                var ownerIDURL: String?
                var businessHours: BusinessHours?
                
                // Fetch document data for restaurants
                if role == .restaurant {
                    if let documents = userData["documents"] as? [String: Any] {
                        documentStatus = documents["status"] as? String
                        if let files = documents["files"] as? [String: Any] {
                            if let restaurantProof = files["restaurant_proof"] as? [String: Any] {
                                restaurantProofURL = restaurantProof["url"] as? String
                            }
                            if let ownerID = files["owner_id"] as? [String: Any] {
                                ownerIDURL = ownerID["url"] as? String
                            }
                        }
                    }
                    
                    if let hours = userData["hours"] as? [String: String] {
                        businessHours = BusinessHours(
                            opening: hours["opening"] ?? "N/A",
                            closing: hours["closing"] ?? "N/A"
                        )
                    }
                }
                
                let user = UserData(
                    id: snapshot.key,
                    fullName: fullName,
                    email: email,
                    phone: phone,
                    role: role,
                    documentStatus: documentStatus,
                    restaurantProofURL: restaurantProofURL,
                    ownerIDURL: ownerIDURL,
                    businessHours: businessHours
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
    
    func updateDocumentStatus(userId: String, status: String, completion: @escaping (Error?) -> Void) {
        let updates = [
            "documents/status": status
        ]
        
        db.child("restaurants").child(userId).updateChildValues(updates) { error, _ in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error)
                } else {
                    // Update the local users array
                    if let index = self.users.firstIndex(where: { $0.id == userId }) {
                        self.users[index].documentStatus = status
                    }
                    completion(nil)
                }
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
    let locationManager: CustomLocationManager
    let authViewModel: AuthViewModel
    
    var body: some View {
        VStack {
            Text("Welcome Customer")
                .font(.title)
                .padding()
        }
    }
}

struct AdminDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: AdminTab? = nil
    
    enum AdminTab: Identifiable {
        case userManagement
        case chatManagement
        
        var id: Self { self }
    }
    var body: some View {
        VStack(spacing: 20) {
            // Logo
            Image("deligo_logo") // Ensure this asset exists in your project
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

#Preview {
    HomeView(authViewModel: AuthViewModel())
} 
