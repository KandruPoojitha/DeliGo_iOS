import SwiftUI
import FirebaseDatabase
import GooglePlaces
import CoreLocation

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    @Published var isFrench: Bool {
        didSet {
            UserDefaults.standard.set(isFrench, forKey: "isFrench")
            // Update the app's language
            if isFrench {
                UserDefaults.standard.set(["fr"], forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            }
            UserDefaults.standard.synchronize()
            // Post notification for app-wide language update
            NotificationCenter.default.post(name: Notification.Name("LanguageChanged"), object: nil)
        }
    }
    
    private init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        self.isFrench = UserDefaults.standard.bool(forKey: "isFrench")
    }
    
    func localizedString(_ key: String) -> String {
        let path = isFrench ? "fr" : "en"
        if let bundlePath = Bundle.main.path(forResource: path, ofType: "lproj"),
           let bundle = Bundle(path: bundlePath) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        return key
    }
}

struct StoreHours: Codable {
    var monday: DayHours
    var tuesday: DayHours
    var wednesday: DayHours
    var thursday: DayHours
    var friday: DayHours
    var saturday: DayHours
    var sunday: DayHours
    
    init() {
        self.monday = DayHours()
        self.tuesday = DayHours()
        self.wednesday = DayHours()
        self.thursday = DayHours()
        self.friday = DayHours()
        self.saturday = DayHours()
        self.sunday = DayHours()
    }
}

struct DayHours: Codable {
    var isOpen: Bool
    var openTime: String
    var closeTime: String
    
    init() {
        self.isOpen = true
        self.openTime = "09:00"
        self.closeTime = "22:00"
    }
}

struct StoreInfo: Codable {
    var name: String
    var address: String
    var phone: String
    var email: String
    var description: String
    var priceRange: PriceRange
    
    init() {
        self.name = ""
        self.address = ""
        self.phone = ""
        self.email = ""
        self.description = ""
        self.priceRange = PriceRange()
    }
    
    // Add a static method to create a default StoreInfo
    static func defaultInfo(from authViewModel: AuthViewModel) -> StoreInfo {
        var info = StoreInfo()
        info.name = authViewModel.fullName ?? "My Restaurant"
        info.email = authViewModel.email ?? ""
        info.phone = authViewModel.phone ?? ""
        info.address = "Enter your address"
        return info
    }
}

struct PriceRange: Codable {
    var min: Int
    var max: Int
    
    init() {
        self.min = 5
        self.max = 25
    }
    
    init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }
}

struct RestaurantAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var appSettings = AppSettings.shared
    @State private var storeHours = StoreHours()
    @State private var storeInfo = StoreInfo()
    @State private var showingHoursSheet = false
    @State private var showingInfoSheet = false
    private var databaseRef: DatabaseReference = Database.database().reference()
    
    // Add explicit public initializer
    public init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "F4A261"))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.fullName ?? "Restaurant Owner")
                                .font(.headline)
                            Text(authViewModel.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text(appSettings.localizedString("store_settings"))) {
                    Button(action: {
                        showingHoursSheet = true
                    }) {
                        HStack {
                            Image(systemName: "clock")
                            Text(appSettings.localizedString("store_hours"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: {
                        showingInfoSheet = true
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text(appSettings.localizedString("store_info"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("Reports")) {
                    NavigationLink(destination: SalesReportsView(authViewModel: authViewModel)) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("Sales Reports")
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text("Admin Support")) {
                    NavigationLink(destination: RestaurantChatView(
                        orderId: "admin_support", 
                        customerId: "admin",
                        customerName: "Admin Support",
                        authViewModel: authViewModel)) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Support Messages")
                            Spacer()
                        }
                    }
                    .onAppear {
                        // Make sure user data is loaded before navigating
                        authViewModel.loadUserProfile()
                    }
                }
                
                Section(header: Text(appSettings.localizedString("appearance"))) {
                    Toggle(isOn: $appSettings.isDarkMode) {
                        HStack {
                            Image(systemName: appSettings.isDarkMode ? "moon.fill" : "moon")
                            Text(appSettings.localizedString("dark_mode"))
                        }
                    }
                }
                
                Section(header: Text(appSettings.localizedString("language"))) {
                    Toggle(isOn: $appSettings.isFrench) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Français")
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text(appSettings.localizedString("sign_out"))
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(appSettings.localizedString("account"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingHoursSheet) {
                StoreHoursView(storeHours: $storeHours, appSettings: appSettings, authViewModel: authViewModel)
            }
            .sheet(isPresented: $showingInfoSheet) {
                StoreInfoView(storeInfo: $storeInfo, appSettings: appSettings, authViewModel: authViewModel)
            }
            .preferredColorScheme(appSettings.isDarkMode ? .dark : .light)
            .onAppear {
                setupRealtimeStoreUpdates()
            }
            .onDisappear {
                removeStoreObservers()
            }
        }
        .background(appSettings.isDarkMode ? Color.black : Color.white)
        .navigationViewStyle(StackNavigationViewStyle())
        .edgesIgnoringSafeArea(.all)
    }
    
    private func setupRealtimeStoreUpdates() {
        guard let userId = authViewModel.currentUserId else { return }
        
        print("DEBUG: Setting up real-time store updates for restaurant ID: \(userId)")
        
        // Initialize with default values first
        self.storeInfo = StoreInfo.defaultInfo(from: authViewModel)
        
        // Set up real-time listeners for store_info
        let storeInfoRef = databaseRef.child("restaurants").child(userId).child("store_info")
        storeInfoRef.observe(.value) { snapshot, _ in
            if snapshot.exists() {
                print("DEBUG: Real-time update received for store_info")
                if let value = snapshot.value as? [String: Any] {
                    DispatchQueue.main.async {
                        var info = StoreInfo()
                        info.name = value["name"] as? String ?? self.authViewModel.fullName ?? "My Restaurant"
                        info.phone = value["phone"] as? String ?? ""
                        info.email = value["email"] as? String ?? self.authViewModel.email ?? ""
                        info.description = value["description"] as? String ?? ""
                        
                        // Get the address from store_info
                        info.address = value["address"] as? String ?? ""
                        print("DEBUG: Real-time store_info address: \(info.address)")
                        
                        // Extract price range data
                        if let priceRangeData = value["price_range"] as? [String: Any] {
                            let min = priceRangeData["min"] as? Int ?? 5
                            let max = priceRangeData["max"] as? Int ?? 25
                            info.priceRange = PriceRange(min: min, max: max)
                        }
                        
                        self.storeInfo = info
                    }
                }
            } else {
                print("DEBUG: No store_info data found in real-time update, using defaults")
            }
        }
        
        // Set up real-time listener for location (as a fallback for address)
        let locationRef = databaseRef.child("restaurants").child(userId).child("location")
        locationRef.observe(.value) { snapshot, _ in
            if snapshot.exists() {
                print("DEBUG: Real-time update received for location")
                if let value = snapshot.value as? [String: Any],
                   let address = value["address"] as? String, 
                   !address.isEmpty {
                    print("DEBUG: Real-time location address: \(address)")
                    
                    // Only update if store_info address is empty
                    DispatchQueue.main.async {
                        if self.storeInfo.address.isEmpty {
                            print("DEBUG: Using location address as store_info address is empty")
                            self.storeInfo.address = address
                        }
                    }
                }
            }
        }
        
        // Set up real-time listener for store hours
        let hoursRef = databaseRef.child("restaurants").child(userId).child("store_hours")
        hoursRef.observe(.value) { snapshot, _ in
            if snapshot.exists(), let value = snapshot.value as? [String: Any] {
                print("DEBUG: Real-time update received for store hours")
                do {
                    let data = try JSONSerialization.data(withJSONObject: value)
                    let hours = try JSONDecoder().decode(StoreHours.self, from: data)
                    
                    DispatchQueue.main.async {
                        self.storeHours = hours
                    }
                    
                    print("DEBUG: Successfully updated store hours from real-time data")
                } catch {
                    print("ERROR: Failed to decode store hours: \(error)")
                }
            }
        }
    }
    
    private func removeStoreObservers() {
        guard let userId = authViewModel.currentUserId else { return }
        
        print("DEBUG: Removing Firebase observers for restaurant profile")
        databaseRef.child("restaurants").child(userId).child("store_info").removeAllObservers()
        databaseRef.child("restaurants").child(userId).child("location").removeAllObservers()
        databaseRef.child("restaurants").child(userId).child("store_hours").removeAllObservers()
    }
}

struct StoreHoursView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var storeHours: StoreHours
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            Form {
                DayHoursSection(day: appSettings.localizedString("monday"), hours: $storeHours.monday)
                DayHoursSection(day: appSettings.localizedString("tuesday"), hours: $storeHours.tuesday)
                DayHoursSection(day: appSettings.localizedString("wednesday"), hours: $storeHours.wednesday)
                DayHoursSection(day: appSettings.localizedString("thursday"), hours: $storeHours.thursday)
                DayHoursSection(day: appSettings.localizedString("friday"), hours: $storeHours.friday)
                DayHoursSection(day: appSettings.localizedString("saturday"), hours: $storeHours.saturday)
                DayHoursSection(day: appSettings.localizedString("sunday"), hours: $storeHours.sunday)
            }
            .navigationTitle(appSettings.localizedString("store_hours"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localizedString("done")) {
                        saveHours()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveHours() {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        do {
            let data = try JSONEncoder().encode(storeHours)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                db.child("restaurants").child(userId).child("store_hours").setValue(dict)
            }
        } catch {
            print("Error saving store hours: \(error)")
        }
    }
}

struct DayHoursSection: View {
    let day: String
    @Binding var hours: DayHours
    
    var body: some View {
        Section(header: Text(day)) {
            Toggle(AppSettings.shared.localizedString("open"), isOn: $hours.isOpen)
            
            if hours.isOpen {
                HStack {
                    Text(AppSettings.shared.localizedString("open"))
                    Spacer()
                    TextField("09:00", text: $hours.openTime)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text(AppSettings.shared.localizedString("close"))
                    Spacer()
                    TextField("22:00", text: $hours.closeTime)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }
        }
    }
}

struct StoreInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var storeInfo: StoreInfo
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var authViewModel: AuthViewModel
    @State private var searchResults: [GMSAutocompletePrediction] = []
    @State private var showingAddressSuggestions = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    
    private let placesClient = GMSPlacesClient.shared()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(appSettings.localizedString("contact_information"))) {
                    // Store Name field
                    TextField(appSettings.localizedString("store_name"), text: $storeInfo.name)
                        .onAppear {
                            if storeInfo.name.isEmpty {
                                storeInfo.name = authViewModel.fullName ?? ""
                            }
                        }
                    
                    // Address field with suggestions
                    VStack(alignment: .leading, spacing: 0) {
                        TextField(appSettings.localizedString("address"), text: $storeInfo.address)
                            .placeholder(when: storeInfo.address.isEmpty) {
                                Text("Enter your restaurant address")
                                    .foregroundColor(.gray)
                                    .opacity(0.7)
                            }
                            .onChange(of: storeInfo.address) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    searchAddressSafely(newValue)
                                    showingAddressSuggestions = true
                                } else {
                                    showingAddressSuggestions = false
                                    searchResults = []
                                }
                            }
                        
                        if showingAddressSuggestions && !searchResults.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading) {
                                    ForEach(searchResults, id: \.placeID) { prediction in
                                        Button(action: {
                                            selectLocationSafely(prediction)
                                            showingAddressSuggestions = false
                                        }) {
                                            Text(prediction.attributedPrimaryText.string)
                                                .lineLimit(1)
                                        }
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding()
                            }
                            .frame(height: 200)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Phone field
                    TextField(appSettings.localizedString("phone"), text: $storeInfo.phone)
                        .keyboardType(.phonePad)
                        .onAppear {
                            if storeInfo.phone.isEmpty {
                                storeInfo.phone = authViewModel.phone ?? ""
                            }
                        }
                    
                    // Email field
                    TextField(appSettings.localizedString("email"), text: $storeInfo.email)
                        .keyboardType(.emailAddress)
                        .onAppear {
                            if storeInfo.email.isEmpty {
                                storeInfo.email = authViewModel.email ?? ""
                            }
                        }
                }
                
                // Price Range Section
                Section(header: Text(appSettings.localizedString("price_range"))) {
                    HStack {
                        Text("Min: $\(storeInfo.priceRange.min)")
                        Spacer()
                        Text("Max: $\(storeInfo.priceRange.max)")
                    }
                    
                    HStack {
                        Text("$")
                        Slider(value: Binding(
                            get: { Double(storeInfo.priceRange.min) },
                            set: { storeInfo.priceRange.min = Int($0) }
                        ), in: 1...Double(storeInfo.priceRange.max), step: 1)
                        Text("$$$")
                    }
                    
                    HStack {
                        Text("$")
                        Slider(value: Binding(
                            get: { Double(storeInfo.priceRange.max) },
                            set: { storeInfo.priceRange.max = Int($0) }
                        ), in: Double(storeInfo.priceRange.min)...100, step: 1)
                        Text("$$$")
                    }
                }
                
                Section(header: Text(appSettings.localizedString("about"))) {
                    TextEditor(text: $storeInfo.description)
                        .frame(height: 100)
                }
            }
            .navigationTitle(storeInfo.name.isEmpty ? appSettings.localizedString("store_info") : storeInfo.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localizedString("save")) {
                        saveInfoSafely()
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showError, content: {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            })
        }
        .onAppear {
            if storeInfo.address.isEmpty {
                print("DEBUG: Address is empty on StoreInfoView appear")
                // Try to load address directly if it's empty
                if let userId = authViewModel.currentUserId {
                    let db = Database.database().reference()
                    
                    // First try to get from store_info
                    db.child("restaurants").child(userId).child("store_info").child("address").observeSingleEvent(of: .value) { snapshot in
                        if let address = snapshot.value as? String, !address.isEmpty {
                            print("DEBUG: Found address in store_info: \(address)")
                            DispatchQueue.main.async {
                                self.storeInfo.address = address
                            }
                        } else {
                            print("DEBUG: No address in store_info, checking location")
                            // Try from location as fallback
                            db.child("restaurants").child(userId).child("location").child("address").observeSingleEvent(of: .value) { snapshot in
                                if let address = snapshot.value as? String, !address.isEmpty {
                                    print("DEBUG: Found address in location: \(address)")
                                    DispatchQueue.main.async {
                                        self.storeInfo.address = address
                                    }
                                } else {
                                    print("DEBUG: No address found in any location")
                                }
                            }
                        }
                    }
                }
            } else {
                print("DEBUG: Address is present: \(storeInfo.address)")
            }
        }
    }
    
    private func searchAddressSafely(_ query: String) {
        do {
            let filter = GMSAutocompleteFilter()
            filter.countries = ["CA"]
            filter.types = ["address"]
            
            placesClient.findAutocompletePredictions(
                fromQuery: query,
                filter: filter,
                sessionToken: nil
            ) { (results, error) in
                if let error = error {
                    print("DEBUG: Error fetching autocomplete results: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Could not search for address: \(error.localizedDescription)"
                        self.showError = true
                        self.searchResults = []
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.searchResults = results ?? []
                }
            }
        } catch {
            print("DEBUG: Error during address search: \(error.localizedDescription)")
            self.errorMessage = "Error searching for address"
            self.showError = true
        }
    }
    
    private func selectLocationSafely(_ prediction: GMSAutocompletePrediction) {
        do {
            let fields: GMSPlaceField = [.name, .formattedAddress, .coordinate]
            
            placesClient.fetchPlace(
                fromPlaceID: prediction.placeID,
                placeFields: fields,
                sessionToken: nil
            ) { (place, error) in
                if let error = error {
                    print("DEBUG: Error fetching place details: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Could not get address details: \(error.localizedDescription)"
                        self.showError = true
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    if let place = place {
                        let formattedAddress = place.formattedAddress ?? prediction.attributedPrimaryText.string
                        print("DEBUG: Selected address: \(formattedAddress)")
                        storeInfo.address = formattedAddress
                        
                        // Save location data
                        guard let userId = authViewModel.currentUserId else { return }
                        let db = Database.database().reference()
                        
                        let locationData: [String: Any] = [
                            "name": place.name ?? "",
                            "address": formattedAddress,
                            "latitude": place.coordinate.latitude,
                            "longitude": place.coordinate.longitude
                        ]
                        
                        db.child("restaurants").child(userId).child("location").setValue(locationData)
                    }
                }
            }
        } catch {
            print("DEBUG: Error during location selection: \(error.localizedDescription)")
            self.errorMessage = "Error selecting location"
            self.showError = true
        }
    }
    
    private func saveInfoSafely() {
        do {
            if storeInfo.address.isEmpty {
                self.errorMessage = "Please enter an address for your restaurant"
                self.showError = true
                return
            }
            
            // Use the existing saveInfo functionality
            saveInfo()
        } catch {
            print("DEBUG: Error during save: \(error.localizedDescription)")
            self.errorMessage = "Error saving information"
            self.showError = true
        }
    }
    
    private func saveInfo() {
        guard let userId = authViewModel.currentUserId else { 
            print("ERROR: Cannot save - user ID is missing")
            return 
        }
        
        print("DEBUG: Saving store info for user: \(userId)")
        print("DEBUG: Address being saved: \(storeInfo.address)")
        
        // Check if address is empty and show alert if it is
        if storeInfo.address.isEmpty || storeInfo.address == "Enter your address" {
            // Show an alert to the user about the missing address
            errorMessage = "Please enter a valid address for your restaurant"
            showError = true
            return
        }
        
        let db = Database.database().reference()
        
        // Save to store_info node
        do {
            let data = try JSONEncoder().encode(storeInfo)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Make sure address is explicitly included in the dictionary
                var updatedDict = dict
                updatedDict["address"] = storeInfo.address
                
                db.child("restaurants").child(userId).child("store_info").setValue(updatedDict) { error, _ in
                    if let error = error {
                        print("ERROR: Failed to save store info: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.errorMessage = "Could not save store info: \(error.localizedDescription)"
                            self.showError = true
                        }
                    } else {
                        print("DEBUG: Successfully saved store info with address: \(self.storeInfo.address)")
                    }
                }
            }
        } catch {
            print("ERROR: Failed to encode store info: \(error)")
            self.errorMessage = "Error preparing store info for saving"
            self.showError = true
        }
        
        // Also update the address in the location node
        // First check if location node exists
        db.child("restaurants").child(userId).child("location").observeSingleEvent(of: .value) { snapshot in
            if var locationData = snapshot.value as? [String: Any] {
                // Location exists, update the address
                locationData["address"] = self.storeInfo.address
                db.child("restaurants").child(userId).child("location").updateChildValues(locationData) { error, _ in
                    if let error = error {
                        print("ERROR: Failed to update location address: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Updated address in location node")
                    }
                }
            } else {
                // Location doesn't exist, create a basic entry
                let basicLocationData: [String: Any] = [
                    "address": self.storeInfo.address,
                    "name": self.storeInfo.name,
                    "latitude": 0.0,
                    "longitude": 0.0
                ]
                db.child("restaurants").child(userId).child("location").setValue(basicLocationData) { error, _ in
                    if let error = error {
                        print("ERROR: Failed to create location entry: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Created new location entry with address")
                    }
                }
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    RestaurantAccountView(authViewModel: AuthViewModel())
}
