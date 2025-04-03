import SwiftUI
import FirebaseDatabase
import Charts

struct DishSalesData: Identifiable {
    let id: String
    let name: String
    let category: String
    let totalQuantity: Int
    let totalRevenue: Double
    let imageURL: String?
}

struct BestSellingDishesView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var dishes: [DishSalesData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let database = Database.database().reference()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Loading dish statistics...")
                } else if let error = errorMessage {
                    ErrorView(message: error)
                } else if dishes.isEmpty {
                    EmptyStateView()
                } else {
                    // Top Dishes List
                    VStack(spacing: 16) {
                        ForEach(dishes) { dish in
                            DishSalesCard(dish: dish)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Best Selling Dishes")
        .onAppear {
            loadDishStatistics()
        }
    }
    
    private func loadDishStatistics() {
        guard let restaurantId = authViewModel.currentUserId else {
            errorMessage = "Restaurant ID not found"
            isLoading = false
            return
        }
        
        print("DEBUG: Loading statistics for restaurant: \(restaurantId)")
        isLoading = true
        errorMessage = nil
        
        // Get all orders
        database.child("orders").observeSingleEvent(of: .value) { snapshot in
            print("DEBUG: Got orders snapshot with \(snapshot.childrenCount) orders")
            var dishStats: [String: (quantity: Int, revenue: Double, name: String, imageURL: String?)] = [:]
            let dispatchGroup = DispatchGroup()
            
            for child in snapshot.children {
                guard let orderSnapshot = child as? DataSnapshot,
                      let orderData = orderSnapshot.value as? [String: Any],
                      let orderRestaurantId = orderData["restaurantId"] as? String,
                      orderRestaurantId == restaurantId,
                      let status = orderData["status"] as? String,
                      status == "delivered" else {
                    if let snap = child as? DataSnapshot {
                        print("DEBUG: Skipping order \(snap.key) - doesn't match criteria")
                    }
                    continue 
                }
                
                print("DEBUG: Processing order: \(orderSnapshot.key)")
                dispatchGroup.enter()
                
                // Get items as an array
                if let items = orderData["items"] as? [[String: Any]] {
                    print("DEBUG: Found \(items.count) items in order")
                    
                    for item in items {
                        guard let menuItemId = item["menuItemId"] as? String,
                              let quantity = item["quantity"] as? Int,
                              let name = item["name"] as? String else {
                            print("DEBUG: Skipping item - missing required data")
                            print("DEBUG: Item data: \(item)")
                            continue
                        }
                        
                        // Handle price which might be a String or Double
                        var price: Double = 0.0
                        if let priceString = item["totalPrice"] as? String {
                            price = Double(priceString) ?? 0.0
                        } else if let priceDouble = item["totalPrice"] as? Double {
                            price = priceDouble
                        }
                        
                        let imageURL = item["imageURL"] as? String
                        
                        print("DEBUG: Processing item: \(menuItemId) with quantity: \(quantity) and price: \(price)")
                        print("DEBUG: Full item data: \(item)")
                        
                        // Thread-safe update of dishStats
                        DispatchQueue.main.async {
                            let currentStats = dishStats[menuItemId] ?? (quantity: 0, revenue: 0, name: name, imageURL: imageURL)
                            dishStats[menuItemId] = (
                                quantity: currentStats.quantity + quantity,
                                revenue: currentStats.revenue + price,
                                name: name,
                                imageURL: imageURL
                            )
                            print("DEBUG: Updated stats for \(menuItemId): Quantity: \(currentStats.quantity + quantity), Revenue: \(currentStats.revenue + price)")
                        }
                    }
                } else {
                    print("DEBUG: No items found in order \(orderSnapshot.key)")
                    print("DEBUG: Order data: \(orderData)")
                }
                dispatchGroup.leave()
            }
            
            // When all items have been processed
            dispatchGroup.notify(queue: .main) {
                print("DEBUG: Processing final statistics")
                // Convert stats to DishSalesData objects
                var dishSalesData: [DishSalesData] = []
                for (itemId, stats) in dishStats {
                    print("DEBUG: Creating dish with ID: \(itemId)")
                    let dish = DishSalesData(
                        id: itemId,
                        name: stats.name,
                        category: "Main Course", // Default category since we don't have it in orders
                        totalQuantity: stats.quantity,
                        totalRevenue: stats.revenue,
                        imageURL: stats.imageURL
                    )
                    dishSalesData.append(dish)
                    print("DEBUG: Added dish to statistics: \(stats.name) - Quantity: \(stats.quantity), Revenue: \(stats.revenue)")
                }
                
                // Sort by quantity sold (descending)
                dishSalesData.sort { $0.totalQuantity > $1.totalQuantity }
                
                self.dishes = dishSalesData
                self.isLoading = false
                print("DEBUG: Finished loading statistics. Found \(dishSalesData.count) dishes")
            }
        }
    }
}

struct DishSalesCard: View {
    let dish: DishSalesData
    
    var body: some View {
        HStack(spacing: 12) {
            // Dish image
            if let imageURL = dish.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Dish details
            VStack(alignment: .leading, spacing: 4) {
                Text(dish.name)
                    .font(.headline)
                
                Text(dish.category)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .foregroundColor(.blue)
                        Text("\(dish.totalQuantity) sold")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                        Text("$\(String(format: "%.2f", dish.totalRevenue))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Sales Data")
                .font(.headline)
            
            Text("Start selling to see your best performing dishes")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView {
        BestSellingDishesView(authViewModel: AuthViewModel())
    }
} 