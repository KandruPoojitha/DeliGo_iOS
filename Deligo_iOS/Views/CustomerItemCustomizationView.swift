import SwiftUI
import FirebaseDatabase

struct CartItem: Identifiable, Equatable, Codable {
    let id: String
    let menuItemId: String
    let name: String
    let description: String
    let price: Double
    let imageURL: String?
    let quantity: Int
    let customizations: [String: [CustomizationSelection]]
    let specialInstructions: String
    let totalPrice: Double
    
    private enum CodingKeys: String, CodingKey {
        case id
        case menuItemId
        case name
        case description
        case price
        case imageURL
        case quantity
        case customizations
        case specialInstructions
        case totalPrice
    }
    
    static func == (lhs: CartItem, rhs: CartItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.menuItemId == rhs.menuItemId &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.price == rhs.price &&
        lhs.imageURL == rhs.imageURL &&
        lhs.quantity == rhs.quantity &&
        lhs.totalPrice == rhs.totalPrice &&
        lhs.specialInstructions == rhs.specialInstructions &&
        NSDictionary(dictionary: lhs.customizations) == NSDictionary(dictionary: rhs.customizations)
    }
}

struct CustomizationSelection: Codable, Equatable {
    let optionId: String
    let optionName: String
    let selectedItems: [SelectedItem]
}

struct SelectedItem: Codable, Equatable {
    let id: String
    let name: String
    let price: Double
}

struct CustomerItemCustomizationView: View {
    let item: MenuItem
    @Binding var isPresented: Bool
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var cartManager: CartManager
    @State private var selectedOptions: [String: Set<String>] = [:]
    @State private var quantity = 1
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var specialInstructions: String = ""
    
    init(item: MenuItem, isPresented: Binding<Bool>, authViewModel: AuthViewModel) {
        self.item = item
        self._isPresented = isPresented
        self.authViewModel = authViewModel
        self._cartManager = ObservedObject(wrappedValue: CartManager(userId: authViewModel.currentUserId ?? ""))
    }
    
    var totalPrice: Double {
        let basePrice = item.price * Double(quantity)
        let customizationPrice = selectedOptions.flatMap { (_, selectedIds) in
            item.customizationOptions.flatMap { option in
                option.options.filter { selectedIds.contains($0.id) }
            }
        }.reduce(0.0) { $0 + $1.price }
        return basePrice + (customizationPrice * Double(quantity))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Item Image and Basic Info
                    if let imageURL = item.imageURL {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(height: 200)
                        .clipped()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(item.description)
                            .font(.body)
                            .foregroundColor(.gray)
                        
                        Text("$\(String(format: "%.2f", item.price))")
                            .font(.headline)
                            .foregroundColor(Color(hex: "F4A261"))
                    }
                    .padding(.horizontal)
                    
                    // Quantity Selector
                    HStack {
                        Text("Quantity")
                            .font(.headline)
                        Spacer()
                        Button(action: { if quantity > 1 { quantity -= 1 } }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(Color(hex: "F4A261"))
                        }
                        Text("\(quantity)")
                            .font(.headline)
                            .padding(.horizontal)
                        Button(action: { quantity += 1 }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hex: "F4A261"))
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Customization Options
                    if !item.customizationOptions.isEmpty {
                        Text("Customize Your Order")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                    
                    ForEach(item.customizationOptions) { option in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(option.name)
                                    .font(.headline)
                                if option.required {
                                    Text("Required")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            if option.type == .single {
                                SingleSelectionOptionView(
                                    option: option,
                                    selectedIds: selectedOptions[option.id] ?? []
                                ) { selectedId in
                                    selectedOptions[option.id] = [selectedId]
                                }
                            } else {
                                MultipleSelectionOptionView(
                                    option: option,
                                    selectedIds: selectedOptions[option.id] ?? []
                                ) { selectedId in
                                    var currentSelection = selectedOptions[option.id] ?? []
                                    if currentSelection.contains(selectedId) {
                                        currentSelection.remove(selectedId)
                                    } else if currentSelection.count < option.maxSelections {
                                        currentSelection.insert(selectedId)
                                    }
                                    selectedOptions[option.id] = currentSelection
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                
                // Special Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Special Instructions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextField("Add any special requests here...", text: $specialInstructions, axis: .vertical)
                        .padding()
                        .frame(minHeight: 80)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .lineLimit(3...5)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.headline)
                    .foregroundColor(Color(hex: "F4A261"))
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("$\(String(format: "%.2f", totalPrice))")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            addToCart()
                        }) {
                            Text("Add to Cart")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 200)
                                .background(isValid ? Color(hex: "F4A261") : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!isValid)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .alert("Cart", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("successfully") {
                        isPresented = false
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isValid: Bool {
        // Check if all required options are selected
        for option in item.customizationOptions where option.required {
            guard let selectedIds = selectedOptions[option.id], !selectedIds.isEmpty else {
                return false
            }
        }
        return true
    }
    
    private func addToCart() {
        guard authViewModel.currentUserId != nil else {
            alertMessage = "Error: User not logged in"
            showingAlert = true
            return
        }
        
        // Debug the original menu item's image URL
        if let imageURL = item.imageURL {
            print("Original menu item has image URL: \(imageURL)")
        } else {
            print("Original menu item has no image URL")
        }
        
        // Create customization selections
        var customizations: [String: [CustomizationSelection]] = [:]
        for option in item.customizationOptions {
            let selectedIds = selectedOptions[option.id] ?? []
            let selectedItems = option.options
                .filter { selectedIds.contains($0.id) }
                .map { SelectedItem(id: $0.id, name: $0.name, price: $0.price) }
            
            if !selectedItems.isEmpty {
                let selection = CustomizationSelection(
                    optionId: option.id,
                    optionName: option.name,
                    selectedItems: selectedItems
                )
                customizations[option.id] = [selection]
            }
        }
        
        // Create cart item
        let cartItem = CartItem(
            id: UUID().uuidString,
            menuItemId: item.id,
            name: item.name,
            description: item.description,
            price: item.price,
            imageURL: item.imageURL,
            quantity: quantity,
            customizations: customizations,
            specialInstructions: specialInstructions,
            totalPrice: totalPrice
        )
        
        // Debug the cart item's image URL
        if let imageURL = cartItem.imageURL {
            print("Cart item created with image URL: \(imageURL)")
        } else {
            print("Cart item created with no image URL")
        }
        
        cartManager.addToCart(item: cartItem)
        alertMessage = "Item added to cart successfully!"
        showingAlert = true
    }
}

struct SingleSelectionOptionView: View {
    let option: CustomizationOption
    let selectedIds: Set<String>
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(option.options) { item in
                Button(action: { onSelect(item.id) }) {
                    HStack {
                        Image(systemName: selectedIds.contains(item.id) ? "circle.fill" : "circle")
                            .foregroundColor(Color(hex: "F4A261"))
                        
                        Text(item.name)
                        
                        Spacer()
                        
                        if item.price > 0 {
                            Text("+$\(String(format: "%.2f", item.price))")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
}

struct MultipleSelectionOptionView: View {
    let option: CustomizationOption
    let selectedIds: Set<String>
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select up to \(option.maxSelections)")
                .font(.caption)
                .foregroundColor(.gray)
            
            ForEach(option.options) { item in
                Button(action: { onSelect(item.id) }) {
                    HStack {
                        Image(systemName: selectedIds.contains(item.id) ? "checkmark.square.fill" : "square")
                            .foregroundColor(Color(hex: "F4A261"))
                        
                        Text(item.name)
                        
                        Spacer()
                        
                        if item.price > 0 {
                            Text("+$\(String(format: "%.2f", item.price))")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
} 