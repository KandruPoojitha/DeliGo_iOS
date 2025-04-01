import SwiftUI
import FirebaseDatabase

struct CustomerMenuItemRow: View {
    let item: MenuItem
    let onTap: () -> Void
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var favoritesManager: FavoritesManager
    
    init(item: MenuItem, onTap: @escaping () -> Void, authViewModel: AuthViewModel, favoritesManager: FavoritesManager) {
        self.item = item
        self.onTap = onTap
        self.authViewModel = authViewModel
        self.favoritesManager = favoritesManager
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let imageURL = item.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        Text("$\(String(format: "%.2f", item.price))")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "F4A261"))
                        
                        if !item.customizationOptions.isEmpty {
                            Text("•")
                            Text("Customizable")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    favoritesManager.toggleFavorite(item: item)
                }) {
                    Image(systemName: favoritesManager.isFavorite(itemId: item.id) ? "heart.fill" : "heart")
                        .foregroundColor(favoritesManager.isFavorite(itemId: item.id) ? .red : .gray)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
    }
} 