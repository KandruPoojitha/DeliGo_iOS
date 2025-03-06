import SwiftUI

struct CustomerFavoritesView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            Text("Favorites")
                .navigationTitle("Favorites")
        }
    }
} 