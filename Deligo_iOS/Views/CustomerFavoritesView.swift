import SwiftUI
import FirebaseDatabase

struct CustomerFavoritesView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var favoriteItems: [MenuItem] = []
    @State private var showCustomizationSheet = false
    @State private var selectedMenuItem: MenuItem?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading favorites...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if favoriteItems.isEmpty {
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
                    List {
                        ForEach(favoriteItems) { item in
                            CustomerMenuItemRow(
                                item: item,
                                onTap: {
                                    selectedMenuItem = item
                                    showCustomizationSheet = true
                                },
                                authViewModel: authViewModel
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Favorites")
            .sheet(isPresented: $showCustomizationSheet) {
                if let item = selectedMenuItem {
                    CustomerItemCustomizationView(
                        item: item,
                        isPresented: $showCustomizationSheet,
                        authViewModel: authViewModel
                    )
                }
            }
        }
        .onAppear {
            loadFavorites()
        }
    }
    
    private func loadFavorites() {
        guard let userId = authViewModel.currentUserId else {
            isLoading = false
            return
        }
        
        let db = Database.database().reference()
        db.child("users").child(userId).child("favorites").observe(.value) { snapshot in
            var items: [MenuItem] = []
            
            for child in snapshot.children {
                guard let snapshot = child as? DataSnapshot,
                      let dict = snapshot.value as? [String: Any] else { continue }
                
                let id = snapshot.key
                let name = dict["name"] as? String ?? ""
                let description = dict["description"] as? String ?? ""
                let price = dict["price"] as? Double ?? 0.0
                let imageURL = dict["imageURL"] as? String
                let category = dict["category"] as? String ?? ""
                
                let item = MenuItem(
                    id: id,
                    name: name,
                    description: description,
                    price: price,
                    imageURL: imageURL,
                    category: category,
                    isAvailable: true,
                    customizationOptions: [] // We'll load customization options when needed
                )
                items.append(item)
            }
            
            // Sort by most recently added
            items.sort { (item1, item2) in
                let timestamp1 = (snapshot.childSnapshot(forPath: item1.id).value as? [String: Any])?["timestamp"] as? Double ?? 0
                let timestamp2 = (snapshot.childSnapshot(forPath: item2.id).value as? [String: Any])?["timestamp"] as? Double ?? 0
                return timestamp1 > timestamp2
            }
            
            DispatchQueue.main.async {
                self.favoriteItems = items
                self.isLoading = false
            }
        }
    }
}

#Preview {
    CustomerFavoritesView(authViewModel: AuthViewModel())
} 