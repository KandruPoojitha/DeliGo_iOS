import Foundation
import GooglePlaces
import Combine

class LocationSearchViewModel: NSObject, ObservableObject {
    @Published var searchText = ""
    @Published var suggestions: [LocationSuggestion] = []
    @Published var selectedLocation: LocationSuggestion?
    
    private var placesClient: GMSPlacesClient
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        self.placesClient = GMSPlacesClient.shared()
        super.init()
        
        setupSearchTextSubscription()
    }
    
    private func setupSearchTextSubscription() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                guard !searchText.isEmpty else {
                    self?.suggestions = []
                    return
                }
                self?.fetchPlacePredictions(for: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func fetchPlacePredictions(for query: String) {
        let filter = GMSAutocompleteFilter()
        filter.countries = ["CA"] // Restrict to Canada
        filter.type = .address
        
        let token = GMSAutocompleteSessionToken.init()
        
        placesClient.findAutocompletePredictions(
            fromQuery: query,
            filter: filter,
            sessionToken: token
        ) { [weak self] predictions, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching predictions: \(error.localizedDescription)")
                    self?.suggestions = []
                    return
                }
                
                self?.suggestions = predictions?.map { prediction in
                    LocationSuggestion(
                        id: UUID(),
                        title: prediction.attributedPrimaryText.string,
                        subtitle: prediction.attributedSecondaryText?.string ?? "",
                        placeID: prediction.placeID,
                        coordinate: CLLocationCoordinate2D()
                    )
                } ?? []
            }
        }
    }
    
    func selectLocation(_ suggestion: LocationSuggestion) {
        let fields: GMSPlaceField = [.name, .formattedAddress, .coordinate]
        
        placesClient.fetchPlace(
            fromPlaceID: suggestion.placeID,
            placeFields: fields,
            sessionToken: nil
        ) { [weak self] place, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching place details: \(error.localizedDescription)")
                    return
                }
                
                guard let place = place else { return }
                
                self?.selectedLocation = LocationSuggestion(
                    id: suggestion.id,
                    title: place.name ?? suggestion.title,
                    subtitle: place.formattedAddress ?? suggestion.subtitle,
                    placeID: suggestion.placeID,
                    coordinate: place.coordinate
                )
            }
        }
    }
} 
