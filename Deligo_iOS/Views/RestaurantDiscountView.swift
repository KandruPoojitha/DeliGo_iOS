import SwiftUI
import FirebaseDatabase

struct RestaurantDiscountView: View {
    let restaurantId: String
    @State private var discount: Int?
    @State private var isLoading = true
    
    private let database = Database.database().reference()
    
    var body: some View {
        Group {
            if isLoading {
                // Show nothing while loading
                EmptyView()
            } else if let discount = discount {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(discount)% off")
                        .foregroundColor(.green)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .onAppear {
            print("DEBUG: RestaurantDiscountView appeared for restaurant: \(restaurantId)")
            loadDiscount()
        }
    }
    
    private func loadDiscount() {
        print("DEBUG: Loading discount for restaurant: \(restaurantId)")
        
        // First try to read the value once
        database.child("restaurants").child(restaurantId).child("discount").observeSingleEvent(of: .value) { snapshot in
            print("DEBUG: Got initial discount snapshot for \(restaurantId): \(String(describing: snapshot.value))")
            handleSnapshot(snapshot)
        }
        
        // Then observe for changes
        database.child("restaurants").child(restaurantId).child("discount").observe(.value) { snapshot in
            print("DEBUG: Got discount update for \(restaurantId): \(String(describing: snapshot.value))")
            handleSnapshot(snapshot)
        }
    }
    
    private func handleSnapshot(_ snapshot: DataSnapshot) {
        if let value = snapshot.value as? Int {
            print("DEBUG: Found discount value: \(value)")
            DispatchQueue.main.async {
                self.discount = value > 0 ? value : nil
                self.isLoading = false
                print("DEBUG: Set discount to \(String(describing: self.discount))")
            }
        } else {
            print("DEBUG: No valid discount found in snapshot")
            DispatchQueue.main.async {
                self.discount = nil
                self.isLoading = false
            }
        }
    }
}

#Preview {
    RestaurantDiscountView(restaurantId: "preview_id")
} 