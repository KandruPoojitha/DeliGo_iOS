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
                        DriverMainView(authViewModel: authViewModel)
                    } else {
                        DriverDocumentsView(authViewModel: authViewModel)
                    }
                case "Admin":
                    AdminView(authViewModel: authViewModel)
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
                                    .id("\(user.id)-\(user.blocked ? "blocked" : "unblocked")") // Force refresh when block status changes
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // If we had a selected role previously, refresh the data
            if let role = selectedRole {
                viewModel.fetchUsers(for: role)
            }
        }
        .onDisappear {
            // View model will clean up its own listeners
        }
    }
}

struct UserCard: View {
    @State var user: UserData
    @State private var showDetailView = false
    @StateObject private var viewModel = UserManagementViewModel()
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name row with status indicator
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(Color(hex: "F4A261"))
                    .font(.system(size: 36))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.headline)
                    
                    if let status = user.documentStatus {
                        Text(status.capitalized)
                            .font(.caption)
                            .foregroundColor(statusColor(for: status))
                    }
                }
                
                Spacer()
                
                // Show blocked status indicator
                if user.blocked {
                    Text("Blocked")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(4)
                }
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
            
            // Debug indicator (will be removed in production)
            Text("Blocked status: \(user.blocked ? "Yes" : "No")")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 4)
            
            // Add block/unblock button for all users
            Divider()
            
            Button(action: {
                toggleUserBlock()
            }) {
                HStack {
                    Image(systemName: user.blocked ? "lock.open.fill" : "lock.fill")
                    Text(user.blocked ? "Unblock User" : "Block User")
                    
                    if isUpdating {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(user.blocked ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isUpdating)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if user.role == .restaurant || user.role == .driver {
                showDetailView = true
            }
        }
        .sheet(isPresented: $showDetailView) {
            if user.role == .restaurant {
                RestaurantDetailView(user: $user)
            } else if user.role == .driver {
                DriverDetailView(user: $user)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            removeObservers()
        }
    }
    
    private func setupNotifications() {
        print("👤 UserCard setup for user: \(user.fullName) (ID: \(user.id)) - Initial blocked status: \(user.blocked)")
        
        let rolePath = "\(user.role.rawValue.lowercased())s"
        let db = Database.database().reference()
        
        let blockedPath = "\(rolePath)/\(user.id)/blocked"
        print("Setting up Firebase observer at path: \(blockedPath)")
        
        db.child(rolePath).child(user.id).child("blocked").observe(.value) { snapshot in
            print("Firebase snapshot received: \(snapshot.key) = \(String(describing: snapshot.value))")
            
            if let isBlocked = snapshot.value as? Bool {
                print("UserCard received real-time update - User \(self.user.id) blocked status is now: \(isBlocked)")
                
                // Update the local user model
                DispatchQueue.main.async {
                    if self.user.blocked != isBlocked {
                        self.user.blocked = isBlocked
                        print("Updated UserCard block status to: \(isBlocked)")
                    }
                }
            }
        }
    }
    
    private func removeObservers() {
        // Remove Firebase observers
        let rolePath = "\(user.role.rawValue.lowercased())s"
        let db = Database.database().reference()
        
        let blockedPath = "\(rolePath)/\(user.id)/blocked"
        print("📡 Removing Firebase observer at path: \(blockedPath)")
        
        // Remove the specific observer for blocked status
        db.child(rolePath).child(user.id).child("blocked").removeAllObservers()
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
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
    
    private func toggleUserBlock() {
        isUpdating = true
        print("🔄 Starting to toggle block status for user: \(user.id) - Current blocked status: \(user.blocked)")
        
        viewModel.toggleUserBlock(userId: user.id, userRole: user.role, currentBlocked: user.blocked) { error in
            isUpdating = false
            if let error = error {
                errorMessage = "Failed to update user: \(error.localizedDescription)"
                showError = true
                print("❌ Error updating block status: \(error.localizedDescription)")
            } else {
                // Temporarily update the UI until the Firebase listener kicks in
                // This makes the UI feel more responsive
                DispatchQueue.main.async {
                    self.user.blocked = !self.user.blocked
                    print("✅ Temporarily updated UI to blocked status: \(self.user.blocked)")
                }
                print("✅ Successfully requested block status change")
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
        viewModel.updateDocumentStatus(userId: user.id, userRole: .restaurant, status: status) { error in
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
    var blocked: Bool = false
    // Document related fields
    var documentStatus: String?
    var documentsSubmitted: Bool?
    // Restaurant specific fields
    var restaurantProofURL: String?
    var ownerIDURL: String?
    var businessHours: BusinessHours?
    // Driver specific fields
    var governmentIDURL: String?
    var driverLicenseURL: String?
}

struct BusinessHours: Codable {
    let opening: String
    let closing: String
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

struct DriverDetailView: View {
    @Binding var user: UserData
    @StateObject private var viewModel = UserManagementViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDocumentPreview = false
    @State private var selectedImageURL: String?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var driverRating: Double?
    @State private var totalRides: Int?
    @State private var rejectedOrdersCount: Int?
    
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
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Rating Section (Only shown for approved drivers)
                    if user.documentStatus?.lowercased() == "approved" {
                        GroupBox(label: Text("Performance").bold()) {
                            VStack(alignment: .leading, spacing: 12) {
                                if let rating = driverRating {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text("Rating: \(String(format: "%.1f", rating))")
                                            .fontWeight(.medium)
                                    }
                                }
                                
                                if let rides = totalRides {
                                    HStack {
                                        Image(systemName: "car.fill")
                                            .foregroundColor(Color(hex: "F4A261"))
                                        Text("Total Rides: \(rides)")
                                            .fontWeight(.medium)
                                    }
                                }
                                
                                if let rejected = rejectedOrdersCount {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                        Text("Rejected Orders: \(rejected)")
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Documents Section
                    GroupBox(label: Text("Documents").bold()) {
                        VStack(alignment: .leading, spacing: 16) {
                            if let governmentIDURL = user.governmentIDURL {
                                Button(action: {
                                    selectedImageURL = governmentIDURL
                                    showDocumentPreview = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                        Text("View Government ID")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            if let driverLicenseURL = user.driverLicenseURL {
                                Button(action: {
                                    selectedImageURL = driverLicenseURL
                                    showDocumentPreview = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                        Text("View Driver's License")
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
            .navigationTitle("Driver Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if user.documentStatus?.lowercased() == "approved" {
                    loadDriverRating()
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
        viewModel.updateDocumentStatus(userId: user.id, userRole: .driver, status: status) { error in
            if let error = error {
                errorMessage = "Failed to update status: \(error.localizedDescription)"
                showError = true
            } else {
                user.documentStatus = status
            }
        }
    }
    
    private func loadDriverRating() {
        let db = Database.database().reference()
        
        // Load ratings
        db.child("drivers").child(user.id).child("ratingsandcomments").child("rating").observeSingleEvent(of: .value) { snapshot in
            if let ratings = snapshot.value as? [String: Int] {
                // Calculate average rating
                var totalRating = 0
                for (_, rating) in ratings {
                    totalRating += rating
                }
                let averageRating = Double(totalRating) / Double(ratings.count)
                
                DispatchQueue.main.async {
                    self.driverRating = averageRating
                }
            } else {
                DispatchQueue.main.async {
                    self.driverRating = 0.0
                }
            }
        }
        
        // Load rejected orders count
        db.child("drivers").child(user.id).child("rejectedOrdersCount").observeSingleEvent(of: .value) { snapshot in
            if let count = snapshot.value as? Int {
                DispatchQueue.main.async {
                    self.rejectedOrdersCount = count
                }
            } else {
                DispatchQueue.main.async {
                    self.rejectedOrdersCount = 0
                }
            }
        }
        
        // Load total completed rides
        db.child("orders").queryOrdered(byChild: "driverId").queryEqual(toValue: user.id).observeSingleEvent(of: .value) { snapshot in
            var completedRides = 0
            
            for child in snapshot.children {
                guard let orderSnapshot = child as? DataSnapshot,
                      let orderData = orderSnapshot.value as? [String: Any],
                      let status = orderData["status"] as? String,
                      status.lowercased() == "delivered" else {
                    continue
                }
                completedRides += 1
            }
            
            DispatchQueue.main.async {
                self.totalRides = completedRides
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(authViewModel: AuthViewModel())
    }
} 
