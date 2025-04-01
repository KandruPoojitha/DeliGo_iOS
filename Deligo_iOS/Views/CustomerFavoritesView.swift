import SwiftUI
import FirebaseDatabase

struct CustomerFavoritesView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var favoritesManager: FavoritesManager
    @State private var isLoading = true
    @State private var selectedItem: MenuItem?
    @State private var showingItemDetail = false
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        self._favoritesManager = StateObject(wrappedValue: FavoritesManager(userId: authViewModel.currentUserId ?? ""))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading favorites...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if favoritesManager.favoriteItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Favorites Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Items you favorite will appear here")
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(favoritesManager.favoriteItems) { item in
                                CustomerMenuItemRow(item: item, onTap: {
                                    selectedItem = item
                                    showingItemDetail = true
                                }, authViewModel: authViewModel, favoritesManager: favoritesManager)
                                .background(
                                    NavigationLink(
                                        destination: ItemDetailView(item: item, authViewModel: authViewModel),
                                        isActive: Binding(
                                            get: { selectedItem?.id == item.id && showingItemDetail },
                                            set: { if !$0 { selectedItem = nil; showingItemDetail = false } }
                                        )
                                    ) {
                                        EmptyView()
                                    }
                                )
                                Divider()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
        }
        .onAppear {
            isLoading = false // Since FavoritesManager handles its own loading
        }
    }
}

#Preview {
    CustomerFavoritesView(authViewModel: AuthViewModel())
} 