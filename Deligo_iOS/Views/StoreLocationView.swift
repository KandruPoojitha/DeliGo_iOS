import SwiftUI
import GoogleMaps
import GooglePlaces
import FirebaseDatabase
import CoreLocation

struct Location: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String
}

class LocationSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [GMSAutocompletePrediction] = []
    @Published var selectedLocation: Location?
    @Published var camera = GMSCameraPosition(
        latitude: 37.7749,
        longitude: -122.4194,
        zoom: 12
    )
    
    private var placesClient: GMSPlacesClient
    private var token: GMSAutocompleteSessionToken
    
    init() {
        placesClient = GMSPlacesClient.shared()
        token = GMSAutocompleteSessionToken.init()
    }
    
    func searchAddress(_ address: String) {
        guard !address.isEmpty else {
            searchResults = []
            return
        }
        
        let filter = GMSAutocompleteFilter()
        filter.type = .establishment
        
        placesClient.findAutocompletePredictions(
            fromQuery: address,
            filter: filter,
            sessionToken: token
        ) { [weak self] (results, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching autocomplete results: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self.searchResults = results ?? []
            }
        }
    }
    
    func selectLocation(_ prediction: GMSAutocompletePrediction) {
        let placeID = prediction.placeID
        
        placesClient.fetchPlace(
            fromPlaceID: placeID,
            placeFields: [.name, .coordinate, .formattedAddress],
            sessionToken: token
        ) { [weak self] (place, error) in
            if let error = error {
                print("Error fetching place details: \(error.localizedDescription)")
                return
            }
            
            guard let self = self,
                  let place = place,
                  let name = place.name,
                  let address = place.formattedAddress else {
                return
            }
            
            let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            let coordinate = place.coordinate ?? defaultCoordinate
            
            DispatchQueue.main.async {
                self.selectedLocation = Location(
                    name: name,
                    coordinate: coordinate,
                    address: address
                )
                self.camera = GMSCameraPosition(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    zoom: 15
                )
                // Generate a new token for the next session
                self.token = GMSAutocompleteSessionToken.init()
            }
        }
    }
}

struct StoreLocationView: View {
    @ObservedObject var viewModel = LocationSearchViewModel()
    @ObservedObject var appSettings = AppSettings.shared
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSearchResults = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField(appSettings.localizedString("search_location"), text: $viewModel.searchText)
                        .onChange(of: viewModel.searchText) { newValue in
                            viewModel.searchAddress(newValue)
                            showingSearchResults = !newValue.isEmpty
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                if showingSearchResults && !viewModel.searchResults.isEmpty {
                    // Search Results List
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            ForEach(viewModel.searchResults, id: \.placeID) { result in
                                Button(action: {
                                    viewModel.selectLocation(result)
                                    showingSearchResults = false
                                    viewModel.searchText = result.attributedPrimaryText.string
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(result.attributedPrimaryText.string)
                                            .foregroundColor(.primary)
                                        Text(result.attributedSecondaryText?.string ?? "")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                Divider()
                            }
                        }
                    }
                } else {
                    // Map View using Google Maps
                    GoogleMapView(
                        coordinate: viewModel.selectedLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        zoom: viewModel.selectedLocation != nil ? 15 : 12
                    )
                }
            }
            .navigationTitle(appSettings.localizedString("store_location"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.selectedLocation != nil {
                        Button(appSettings.localizedString("save")) {
                            saveLocation()
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(appSettings.localizedString("cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveLocation() {
        guard let userId = authViewModel.currentUserId,
              let location = viewModel.selectedLocation else { return }
        
        let db = Database.database().reference()
        let locationData: [String: Any] = [
            "name": location.name,
            "address": location.address,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ]
        
        db.child("restaurants").child(userId).child("location").setValue(locationData)
    }
}

struct GoogleMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let zoom: Float
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: coordinate.latitude,
            longitude: coordinate.longitude,
            zoom: zoom
        )
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.animate(to: GMSCameraPosition(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            zoom: zoom
        ))
        
        // Clear existing markers
        mapView.clear()
        
        // Add marker for selected location
        let marker = GMSMarker(position: coordinate)
        marker.map = mapView
    }
}

#Preview {
    StoreLocationView(authViewModel: AuthViewModel())
} 

