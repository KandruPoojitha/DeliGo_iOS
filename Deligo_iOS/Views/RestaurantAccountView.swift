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
    var address: String
    var phone: String
    var email: String
    var description: String
    
    init() {
        self.address = ""
        self.phone = ""
        self.email = ""
        self.description = ""
    }
}

struct RestaurantAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var appSettings = AppSettings.shared
    @State private var storeHours = StoreHours()
    @State private var storeInfo = StoreInfo()
    @State private var showingHoursSheet = false
    @State private var showingInfoSheet = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "F4A261"))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.email ?? "Restaurant Owner")
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
                loadStoreData()
            }
        }
        .background(appSettings.isDarkMode ? Color.black : Color.white)
        .navigationViewStyle(StackNavigationViewStyle())
        .edgesIgnoringSafeArea(.all)
    }
    
    private func loadStoreData() {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        // Load store hours
        db.child("restaurants").child(userId).child("store_hours").observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? [String: Any] {
                do {
                    let data = try JSONSerialization.data(withJSONObject: value)
                    let hours = try JSONDecoder().decode(StoreHours.self, from: data)
                    self.storeHours = hours
                } catch {
                    print("Error decoding store hours: \(error)")
                }
            }
        }
        
        // Load store info
        db.child("restaurants").child(userId).child("store_info").observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? [String: Any] {
                do {
                    let data = try JSONSerialization.data(withJSONObject: value)
                    let info = try JSONDecoder().decode(StoreInfo.self, from: data)
                    self.storeInfo = info
                } catch {
                    print("Error decoding store info: \(error)")
                }
            }
        }
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
    private let placesClient = GMSPlacesClient.shared()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(appSettings.localizedString("contact_information"))) {
                    // Address field with suggestions
                    VStack(alignment: .leading, spacing: 0) {
                        TextField(appSettings.localizedString("address"), text: $storeInfo.address)
                            .onChange(of: storeInfo.address) { newValue in
                                if !newValue.isEmpty {
                                    searchAddress(newValue)
                                    showingAddressSuggestions = true
                                } else {
                                    showingAddressSuggestions = false
                                    searchResults = []
                                }
                            }
                        
                        if showingAddressSuggestions && !searchResults.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(searchResults, id: \.placeID) { result in
                                        Button(action: {
                                            selectLocation(result)
                                            showingAddressSuggestions = false
                                        }) {
                                            HStack {
                                                Text(result.attributedPrimaryText.string)
                                                    .foregroundColor(.primary)
                                                    .font(.system(size: 17))
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(Color(.systemGray3))
                                                    .font(.system(size: 14))
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal)
                                        }
                                        
                                        if result.placeID != searchResults.last?.placeID {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 250)
                            .background(Color(.systemBackground))
                        }
                    }
                    
                    TextField(appSettings.localizedString("phone"), text: $storeInfo.phone)
                        .keyboardType(.phonePad)
                    TextField(appSettings.localizedString("email"), text: $storeInfo.email)
                        .keyboardType(.emailAddress)
                }
                
                Section(header: Text(appSettings.localizedString("about"))) {
                    TextEditor(text: $storeInfo.description)
                        .frame(height: 100)
                }
            }
            .navigationTitle(appSettings.localizedString("store_info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localizedString("save")) {
                        saveInfo()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func searchAddress(_ query: String) {
        let filter = GMSAutocompleteFilter()
        filter.countries = ["CA"] // Restrict to Canada
        filter.type = .address // Only show address results
        
        placesClient.findAutocompletePredictions(
            fromQuery: query,
            filter: filter,
            sessionToken: nil
        ) { (results, error) in
            if let error = error {
                print("Error fetching autocomplete results: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self.searchResults = results ?? []
            }
        }
    }
    
    private func selectLocation(_ prediction: GMSAutocompletePrediction) {
        placesClient.fetchPlace(
            fromPlaceID: prediction.placeID,
            placeFields: [.name, .formattedAddress, .coordinate],
            sessionToken: nil
        ) { (place, error) in
            if let error = error {
                print("Error fetching place details: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                if let place = place {
                    storeInfo.address = place.formattedAddress ?? prediction.attributedPrimaryText.string
                    
                    // Save location data
                    guard let userId = authViewModel.currentUserId else { return }
                    let db = Database.database().reference()
                    
                    let locationData: [String: Any] = [
                        "name": place.name ?? "",
                        "address": place.formattedAddress ?? "",
                        "latitude": place.coordinate.latitude,
                        "longitude": place.coordinate.longitude
                    ]
                    
                    db.child("restaurants").child(userId).child("location").setValue(locationData)
                }
            }
        }
    }
    
    private func saveInfo() {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        do {
            let data = try JSONEncoder().encode(storeInfo)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                db.child("restaurants").child(userId).child("store_info").setValue(dict)
            }
        } catch {
            print("Error saving store info: \(error)")
        }
    }
}

#Preview {
    RestaurantAccountView(authViewModel: AuthViewModel())
}
