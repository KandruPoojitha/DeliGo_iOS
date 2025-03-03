import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseDatabase

struct RestaurantMenuView: View {
    @State private var menuItems: [MenuItem] = []
    @State private var showAddItemSheet = false
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if menuItems.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "fork.knife")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Menu Items")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Add your first menu item")
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        showAddItemSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Item")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "F4A261"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(menuItems) { item in
                        MenuItemRow(item: item, authViewModel: authViewModel, menuItems: $menuItems)
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(InsetGroupedListStyle())
                
                // Add Item Button when items exist
                Button(action: {
                    showAddItemSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Item")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "F4A261"))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddItemSheet) {
            AddMenuItemView(menuItems: $menuItems, authViewModel: authViewModel)
        }
        .onAppear {
            loadMenuItems()
        }
    }
    
    private func loadMenuItems() {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        db.child("restaurants").child(userId).child("menu_items").observe(.value) { snapshot in
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
                let isAvailable = dict["isAvailable"] as? Bool ?? true
                let customizationOptions = dict["customizationOptions"] as? [[String: Any]] ?? []
                
                let options: [CustomizationOption] = customizationOptions.map { optionDict in
                    CustomizationOption(
                        id: optionDict["id"] as? String ?? "",
                        name: optionDict["name"] as? String ?? "",
                        type: CustomizationType(rawValue: optionDict["type"] as? String ?? "single") ?? .single,
                        required: optionDict["required"] as? Bool ?? false,
                        options: (optionDict["options"] as? [[String: Any]] ?? []).map { itemDict in
                            CustomizationItem(
                                id: itemDict["id"] as? String ?? "",
                                name: itemDict["name"] as? String ?? "",
                                price: itemDict["price"] as? Double ?? 0.0
                            )
                        },
                        maxSelections: optionDict["maxSelections"] as? Int ?? 1
                    )
                }
                
                let item = MenuItem(
                    id: id,
                    name: name,
                    description: description,
                    price: price,
                    imageURL: imageURL,
                    category: category,
                    isAvailable: isAvailable,
                    customizationOptions: options
                )
                items.append(item)
            }
            
            self.menuItems = items
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        guard let userId = authViewModel.currentUserId else { return }
        let db = Database.database().reference()
        
        for index in offsets {
            let item = menuItems[index]
            // Delete from Firebase
            db.child("restaurants").child(userId).child("menu_items").child(item.id).removeValue()
            
            // Delete image if exists
            if let imageURL = item.imageURL,
               let url = URL(string: imageURL),
               url.pathComponents.count > 1 {
                let imagePath = url.pathComponents.last!
                let storage = Storage.storage().reference()
                storage.child("menu_items/\(imagePath)").delete { error in
                    if let error = error {
                        print("Error deleting image: \(error)")
                    }
                }
            }
        }
        
        menuItems.remove(atOffsets: offsets)
    }
}

struct MenuItem: Identifiable {
    let id: String
    var name: String
    var description: String
    var price: Double
    var imageURL: String?
    var category: String
    var isAvailable: Bool
    var customizationOptions: [CustomizationOption]
}

struct CustomizationOption: Identifiable, Codable {
    let id: String
    var name: String
    var type: CustomizationType
    var required: Bool
    var options: [CustomizationItem]
    var maxSelections: Int
}

struct CustomizationItem: Identifiable, Codable {
    let id: String
    var name: String
    var price: Double
}

enum CustomizationType: String, Codable {
    case single // Radio buttons (pick one)
    case multiple // Checkboxes (pick multiple)
}

struct MenuItemRow: View {
    let item: MenuItem
    @State private var showEditSheet = false
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var menuItems: [MenuItem]
    
    var body: some View {
        Button(action: {
            showEditSheet = true
        }) {
            HStack(spacing: 12) {
                if let imageURL = item.imageURL {
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
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                        .frame(width: 60, height: 60)
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
                    Text("$\(String(format: "%.2f", item.price))")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "F4A261"))
                }
                
                Spacer()
                
                // Availability Toggle
                Circle()
                    .fill(item.isAvailable ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
            }
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showEditSheet) {
            EditMenuItemView(menuItems: $menuItems, item: item, authViewModel: authViewModel)
        }
    }
}

struct EditMenuItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var menuItems: [MenuItem]
    let item: MenuItem
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var name: String
    @State private var description: String
    @State private var price: String
    @State private var category: String
    @State private var isAvailable: Bool
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedUIImage: UIImage? = nil
    @State private var existingImageURL: String?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var customizationOptions: [CustomizationOption]
    @State private var showingCustomizationSheet = false
    
    let categories = ["Appetizer", "Main Course", "Dessert", "Beverage"]
    
    init(menuItems: Binding<[MenuItem]>, item: MenuItem, authViewModel: AuthViewModel) {
        self._menuItems = menuItems
        self.item = item
        self.authViewModel = authViewModel
        
        // Initialize state variables with existing item data
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _price = State(initialValue: String(format: "%.2f", item.price))
        _category = State(initialValue: item.category)
        _isAvailable = State(initialValue: item.isAvailable)
        _existingImageURL = State(initialValue: item.imageURL)
        _customizationOptions = State(initialValue: item.customizationOptions)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Image")) {
                    VStack(alignment: .center, spacing: 12) {
                        if let uiImage = selectedUIImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                        } else if let existingURL = existingImageURL {
                            AsyncImage(url: URL(string: existingURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .cornerRadius(12)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        PhotosPicker(selection: $selectedImage,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "photo.fill")
                                Text(existingImageURL == nil && selectedUIImage == nil ? "Add Image" : "Change Image")
                            }
                            .foregroundColor(Color(hex: "F4A261"))
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .padding()
                }
                
                Section(header: Text("Item Details")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section(header: Text("Customization Options")) {
                    ForEach(customizationOptions) { option in
                        VStack(alignment: .leading) {
                            Text(option.name)
                                .font(.headline)
                            Text("\(option.type.rawValue) - \(option.required ? "Required" : "Optional")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete { indexSet in
                        customizationOptions.remove(atOffsets: indexSet)
                    }
                    
                    Button(action: {
                        showingCustomizationSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Customization Option")
                        }
                    }
                }
                
                Section {
                    Toggle("Available", isOn: $isAvailable)
                }
            }
            .navigationTitle("Edit Menu Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if isUploading {
                            return
                        }
                        Task {
                            await updateItem()
                        }
                    }
                    .disabled(name.isEmpty || price.isEmpty || isUploading)
                }
            }
            .sheet(isPresented: $showingCustomizationSheet) {
                AddCustomizationView(customizationOptions: $customizationOptions)
            }
            .onChange(of: selectedImage) { _ in
                Task {
                    if let data = try? await selectedImage?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedUIImage = uiImage
                    }
                }
            }
            .overlay {
                if isUploading {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
    
    private func updateItem() async {
        guard let priceValue = Double(price) else { return }
        isUploading = true
        
        var imageURL = existingImageURL
        
        if let selectedImage = selectedImage {
            // Upload new image to Firebase Storage
            if let imageData = try? await selectedImage.loadTransferable(type: Data.self) {
                let storage = Storage.storage().reference()
                
                // Delete existing image if there is one
                if let existingURL = existingImageURL,
                   let url = URL(string: existingURL),
                   url.pathComponents.count > 1 {
                    let imagePath = url.pathComponents.last!
                    let oldImageRef = storage.child("menu_items/\(imagePath)")
                    try? await oldImageRef.delete()
                }
                
                // Upload new image
                let imageRef = storage.child("menu_items/\(UUID().uuidString).jpg")
                
                do {
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    let _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
                    imageURL = try await imageRef.downloadURL().absoluteString
                } catch {
                    print("Error uploading image: \(error)")
                    errorMessage = "Failed to upload image"
                    showError = true
                    isUploading = false
                    return
                }
            }
        }
        
        // Update item in menuItems array
        if let index = menuItems.firstIndex(where: { $0.id == item.id }) {
            let updatedItem = MenuItem(
                id: item.id,
                name: name,
                description: description,
                price: priceValue,
                imageURL: imageURL,
                category: category,
                isAvailable: isAvailable,
                customizationOptions: customizationOptions
            )
            menuItems[index] = updatedItem
        }
        
        // Update in Firebase
        guard let userId = authViewModel.currentUserId else {
            errorMessage = "User ID not found"
            showError = true
            isUploading = false
            return
        }
        
        let db = Database.database().reference()
        var itemData: [String: Any] = [
            "name": name,
            "description": description,
            "price": priceValue,
            "imageURL": imageURL as Any,
            "category": category,
            "isAvailable": isAvailable
        ]
        
        // Add customization options to the data
        if !customizationOptions.isEmpty {
            let customizationData = customizationOptions.map { option -> [String: Any] in
                [
                    "id": option.id,
                    "name": option.name,
                    "type": option.type.rawValue,
                    "required": option.required,
                    "maxSelections": option.maxSelections,
                    "options": option.options.map { item -> [String: Any] in
                        [
                            "id": item.id,
                            "name": item.name,
                            "price": item.price
                        ]
                    }
                ]
            }
            itemData["customizationOptions"] = customizationData
        }
        
        do {
            try await db.child("restaurants").child(userId).child("menu_items").child(item.id).setValue(itemData)
            isUploading = false
            dismiss()
        } catch {
            errorMessage = "Failed to update menu item"
            showError = true
            isUploading = false
        }
    }
}

struct AddMenuItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var menuItems: [MenuItem]
    @ObservedObject var authViewModel: AuthViewModel
    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
    @State private var category = "Main Course"
    @State private var isAvailable = true
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedUIImage: UIImage? = nil
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var customizationOptions: [CustomizationOption] = []
    @State private var showingCustomizationSheet = false
    
    let categories = ["Appetizer", "Main Course", "Dessert", "Beverage"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Image")) {
                    VStack(alignment: .center, spacing: 12) {
                        if let uiImage = selectedUIImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        PhotosPicker(selection: $selectedImage,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "photo.fill")
                                Text(selectedUIImage == nil ? "Add Image" : "Change Image")
                            }
                            .foregroundColor(Color(hex: "F4A261"))
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .padding()
                }
                
                Section(header: Text("Item Details")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section(header: Text("Customization Options")) {
                    ForEach(customizationOptions) { option in
                        VStack(alignment: .leading) {
                            Text(option.name)
                                .font(.headline)
                            Text("\(option.type.rawValue) - \(option.required ? "Required" : "Optional")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: {
                        showingCustomizationSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Customization Option")
                        }
                    }
                }
                
                Section {
                    Toggle("Available", isOn: $isAvailable)
                }
            }
            .navigationTitle("Add Menu Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if isUploading {
                            return
                        }
                        Task {
                            await saveItem()
                        }
                    }
                    .disabled(name.isEmpty || price.isEmpty || isUploading)
                }
            }
            .sheet(isPresented: $showingCustomizationSheet) {
                AddCustomizationView(customizationOptions: $customizationOptions)
            }
            .onChange(of: selectedImage) { _ in
                Task {
                    if let data = try? await selectedImage?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedUIImage = uiImage
                    }
                }
            }
            .overlay {
                if isUploading {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
    
    private func saveItem() async {
        guard let priceValue = Double(price) else { return }
        isUploading = true
        
        var imageURL: String?
        
        if let selectedImage = selectedImage {
            // Upload image to Firebase Storage
            if let imageData = try? await selectedImage.loadTransferable(type: Data.self) {
                let storage = Storage.storage().reference()
                let imageRef = storage.child("menu_items/\(UUID().uuidString).jpg")
                
                do {
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    let _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
                    imageURL = try await imageRef.downloadURL().absoluteString
                } catch {
                    print("Error uploading image: \(error)")
                    errorMessage = "Failed to upload image"
                    showError = true
                    isUploading = false
                    return
                }
            }
        }
        
        let itemId = UUID().uuidString
        let newItem = MenuItem(
            id: itemId,
            name: name,
            description: description,
            price: priceValue,
            imageURL: imageURL,
            category: category,
            isAvailable: isAvailable,
            customizationOptions: customizationOptions
        )
        
        // Save to Firebase Database
        guard let userId = authViewModel.currentUserId else {
            errorMessage = "User ID not found"
            showError = true
            isUploading = false
            return
        }
        
        let db = Database.database().reference()
        var itemData: [String: Any] = [
            "name": name,
            "description": description,
            "price": priceValue,
            "imageURL": imageURL as Any,
            "category": category,
            "isAvailable": isAvailable
        ]
        
        // Add customization options to the data
        if !customizationOptions.isEmpty {
            let customizationData = customizationOptions.map { option -> [String: Any] in
                [
                    "id": option.id,
                    "name": option.name,
                    "type": option.type.rawValue,
                    "required": option.required,
                    "maxSelections": option.maxSelections,
                    "options": option.options.map { item -> [String: Any] in
                        [
                            "id": item.id,
                            "name": item.name,
                            "price": item.price
                        ]
                    }
                ]
            }
            itemData["customizationOptions"] = customizationData
        }
        
        do {
            try await db.child("restaurants").child(userId).child("menu_items").child(itemId).setValue(itemData)
            menuItems.append(newItem)
            isUploading = false
            dismiss()
        } catch {
            errorMessage = "Failed to save menu item"
            showError = true
            isUploading = false
        }
    }
}

struct AddCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var customizationOptions: [CustomizationOption]
    @State private var name = ""
    @State private var type = CustomizationType.single
    @State private var required = false
    @State private var maxSelections = 1
    @State private var options: [CustomizationItem] = []
    @State private var showingAddOptionSheet = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Details")) {
                    TextField("Name (e.g., 'Size' or 'Toppings')", text: $name)
                    Picker("Type", selection: $type) {
                        Text("Single Selection").tag(CustomizationType.single)
                        Text("Multiple Selection").tag(CustomizationType.multiple)
                    }
                    Toggle("Required", isOn: $required)
                    
                    if type == .multiple {
                        Stepper("Max Selections: \(maxSelections)", value: $maxSelections, in: 1...10)
                    }
                }
                
                Section(header: Text("Options")) {
                    ForEach(options) { option in
                        HStack {
                            Text(option.name)
                            Spacer()
                            Text("$\(String(format: "%.2f", option.price))")
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete { indexSet in
                        options.remove(atOffsets: indexSet)
                    }
                    
                    Button(action: {
                        showingAddOptionSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Option")
                        }
                    }
                }
            }
            .navigationTitle("Add Customization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCustomization()
                    }
                    .disabled(name.isEmpty || options.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddOptionSheet) {
                AddOptionView(options: $options)
            }
        }
    }
    
    private func saveCustomization() {
        let newOption = CustomizationOption(
            id: UUID().uuidString,
            name: name,
            type: type,
            required: required,
            options: options,
            maxSelections: maxSelections
        )
        customizationOptions.append(newOption)
        dismiss()
    }
}

struct AddOptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var options: [CustomizationItem]
    @State private var name = ""
    @State private var price = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Option Name", text: $name)
                    TextField("Additional Price", text: $price)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Option")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if let priceValue = Double(price) {
                            let newOption = CustomizationItem(
                                id: UUID().uuidString,
                                name: name,
                                price: priceValue
                            )
                            options.append(newOption)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || price.isEmpty)
                }
            }
        }
    }
}

#Preview {
    RestaurantMenuView(authViewModel: AuthViewModel())
}
