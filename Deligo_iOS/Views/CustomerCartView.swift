import SwiftUI
import FirebaseDatabase

struct CustomerCartView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var cartManager: CartManager
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(authViewModel: AuthViewModel) {
        print("CustomerCartView initialized")
        print("Current user ID: \(authViewModel.currentUserId ?? "nil")")
        self.authViewModel = authViewModel
        self._cartManager = ObservedObject(wrappedValue: CartManager(userId: authViewModel.currentUserId ?? ""))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if cartManager.cartItems.isEmpty {
                    EmptyCartView()
                } else {
                    CartItemsListView(cartManager: cartManager, authViewModel: authViewModel)
                }
            }
            .navigationTitle("Cart")
            .toolbar {
                if !cartManager.cartItems.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAlert = true
                        }) {
                            Text("Clear Cart")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Clear Cart", isPresented: $showingAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    cartManager.clearCart()
                }
            } message: {
                Text("Are you sure you want to clear your cart?")
            }
            .onChange(of: cartManager.cartItems) { items in
                print("Cart items updated. Count: \(items.count)")
            }
        }
    }
}

struct EmptyCartView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Your cart is empty")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add some delicious items to your cart")
                .font(.body)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct CartItemsListView: View {
    @ObservedObject var cartManager: CartManager
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(cartManager.cartItems) { item in
                        CartItemRow(item: item, cartManager: cartManager)
                    }
                }
                .padding()
            }
            
            CartTotalView(totalPrice: cartManager.totalCartPrice, cartManager: cartManager, authViewModel: authViewModel)
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    @ObservedObject var cartManager: CartManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        Text("$\(String(format: "%.2f", item.price))")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "F4A261"))
                        
                        Spacer()
                        
                        QuantityControl(
                            quantity: item.quantity,
                            onDecrease: {
                                if item.quantity > 1 {
                                    cartManager.updateQuantity(itemId: item.id, quantity: item.quantity - 1)
                                }
                            },
                            onIncrease: {
                                cartManager.updateQuantity(itemId: item.id, quantity: item.quantity + 1)
                            }
                        )
                    }
                }
            }
            
            if !item.customizations.isEmpty {
                CustomizationsView(customizations: item.customizations)
            }
            
            HStack {
                Spacer()
                Button(action: {
                    cartManager.removeFromCart(itemId: item.id)
                }) {
                    Text("Remove")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            Divider()
        }
    }
}

struct QuantityControl: View {
    let quantity: Int
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onDecrease) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(Color(hex: "F4A261"))
            }
            
            Text("\(quantity)")
                .font(.headline)
                .frame(minWidth: 30)
            
            Button(action: onIncrease) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(hex: "F4A261"))
            }
        }
    }
}

struct CustomizationsView: View {
    let customizations: [String: [CustomizationSelection]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customizations")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            ForEach(Array(customizations.values.joined()), id: \.optionId) { selection in
                VStack(alignment: .leading, spacing: 4) {
                    Text(selection.optionName)
                        .font(.subheadline)
                    
                    ForEach(selection.selectedItems, id: \.id) { item in
                        HStack {
                            Text("• \(item.name)")
                                .font(.caption)
                            
                            if item.price > 0 {
                                Text("+$\(String(format: "%.2f", item.price))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CartTotalView: View {
    let totalPrice: Double
    @ObservedObject var cartManager: CartManager
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showingCheckout = false
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 16) {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text("$\(String(format: "%.2f", totalPrice))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "F4A261"))
                }
                
                NavigationLink(destination: CheckoutView(cartManager: cartManager, authViewModel: authViewModel)) {
                    Text("Proceed to Checkout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "F4A261"))
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

extension CustomizationSelection: Identifiable {
    var id: String { optionId }
}

extension SelectedItem: Identifiable { } 