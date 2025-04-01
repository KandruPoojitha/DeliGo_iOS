import Foundation
import FirebaseDatabase
import CoreLocation

struct DeliveryOrder: Identifiable {
    let id: String
    let userId: String
    let restaurantId: String
    let restaurantName: String?
    let items: [DeliveryOrderItem]
    let subtotal: Double
    let tipAmount: Double
    let deliveryFee: Double
    let total: Double
    let deliveryOption: String
    let paymentMethod: String
    let status: String
    let orderStatus: String
    let createdAt: TimeInterval
    let address: DeliveryAddress
    var driverId: String?
    var driverName: String?
    
    init?(id: String, data: [String: Any]) {
        print("Attempting to create DeliveryOrder with id: \(id)")
        self.id = id
        
        guard let userId = data["userId"] as? String,
              let restaurantId = data["restaurantId"] as? String,
              let subtotal = data["subtotal"] as? Double,
              let total = data["total"] as? Double,
              let deliveryOption = data["deliveryOption"] as? String,
              let paymentMethod = data["paymentMethod"] as? String,
              let status = data["status"] as? String else {
            print("Failed to initialize DeliveryOrder - Missing required fields")
            print("userId: \(data["userId"] as? String ?? "missing")")
            print("restaurantId: \(data["restaurantId"] as? String ?? "missing")")
            print("subtotal: \(data["subtotal"] as? Double ?? -1)")
            print("total: \(data["total"] as? Double ?? -1)")
            print("deliveryOption: \(data["deliveryOption"] as? String ?? "missing")")
            print("paymentMethod: \(data["paymentMethod"] as? String ?? "missing")")
            print("status: \(data["status"] as? String ?? "missing")")
            return nil
        }
        
        self.userId = userId
        self.restaurantId = restaurantId
        self.restaurantName = data["restaurantName"] as? String
        self.subtotal = subtotal
        self.tipAmount = data["tipAmount"] as? Double ?? 0.0
        self.deliveryFee = data["deliveryFee"] as? Double ?? 0.0
        self.total = total
        self.deliveryOption = deliveryOption
        self.paymentMethod = paymentMethod
        self.status = status
        self.orderStatus = data["order_status"] as? String ?? status
        self.createdAt = data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
        self.driverId = data["driverId"] as? String
        self.driverName = data["driverName"] as? String
        
        // Parse order items
        var orderItems: [DeliveryOrderItem] = []
        if let itemsData = data["items"] as? [[String: Any]] {
            print("Found \(itemsData.count) items")
            for itemData in itemsData {
                if let item = DeliveryOrderItem(data: itemData) {
                    orderItems.append(item)
                }
            }
        }
        self.items = orderItems
        
        // Parse delivery address
        if let addressData = data["address"] as? [String: Any] {
            self.address = DeliveryAddress(
                streetAddress: addressData["street"] as? String ?? "",
                city: addressData["city"] as? String ?? "",
                state: addressData["state"] as? String ?? "",
                zipCode: addressData["zipCode"] as? String ?? "",
                unit: addressData["unit"] as? String,
                instructions: addressData["instructions"] as? String,
                latitude: data["latitude"] as? Double ?? 0.0,
                longitude: data["longitude"] as? Double ?? 0.0,
                placeID: addressData["placeID"] as? String ?? ""
            )
        } else {
            // Default empty address
            self.address = DeliveryAddress(
                streetAddress: "",
                city: "",
                state: "",
                zipCode: "",
                unit: nil,
                instructions: nil,
                latitude: data["latitude"] as? Double ?? 0.0,
                longitude: data["longitude"] as? Double ?? 0.0,
                placeID: ""
            )
        }
        
        print("Successfully created DeliveryOrder with id: \(id)")
    }
    
    // Add a method to convert the order back to a dictionary
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "restaurantId": restaurantId,
            "restaurantName": restaurantName ?? "",
            "subtotal": subtotal,
            "tipAmount": tipAmount,
            "deliveryFee": deliveryFee,
            "total": total,
            "deliveryOption": deliveryOption,
            "paymentMethod": paymentMethod,
            "status": status,
            "order_status": orderStatus,
            "createdAt": createdAt
        ]
        
        if let driverId = driverId {
            dict["driverId"] = driverId
        }
        
        if let driverName = driverName {
            dict["driverName"] = driverName
        }
        
        // Convert address to dictionary
        var addressDict: [String: Any] = [
            "street": address.streetAddress,
            "city": address.city,
            "state": address.state,
            "zipCode": address.zipCode,
            "latitude": address.latitude,
            "longitude": address.longitude,
            "placeID": address.placeID
        ]
        
        if let unit = address.unit {
            addressDict["unit"] = unit
        }
        
        if let instructions = address.instructions {
            addressDict["instructions"] = instructions
        }
        
        dict["address"] = addressDict
        
        // Convert items to array of dictionaries
        var itemsArray: [[String: Any]] = []
        for item in items {
            var itemDict: [String: Any] = [
                "id": item.id,
                "menuItemId": item.menuItemId,
                "name": item.name,
                "description": item.description,
                "price": item.price,
                "quantity": item.quantity,
                "totalPrice": item.totalPrice
            ]
            
            if let imageURL = item.imageURL {
                itemDict["imageURL"] = imageURL
            }
            
            if let specialInstructions = item.specialInstructions {
                itemDict["specialInstructions"] = specialInstructions
            }
            
            // Convert customizations
            if !item.customizations.isEmpty {
                var customizationsDict: [String: [[String: Any]]] = [:]
                for (optionId, selections) in item.customizations {
                    var selectionsArray: [[String: Any]] = []
                    for selection in selections {
                        var selectionDict: [String: Any] = [
                            "optionId": selection.optionId,
                            "optionName": selection.optionName
                        ]
                        
                        var selectedItemsArray: [[String: Any]] = []
                        for selectedItem in selection.selectedItems {
                            let selectedItemDict: [String: Any] = [
                                "id": selectedItem.id,
                                "name": selectedItem.name,
                                "price": selectedItem.price
                            ]
                            selectedItemsArray.append(selectedItemDict)
                        }
                        
                        selectionDict["selectedItems"] = selectedItemsArray
                        selectionsArray.append(selectionDict)
                    }
                    customizationsDict[optionId] = selectionsArray
                }
                itemDict["customizations"] = customizationsDict
            }
            
            itemsArray.append(itemDict)
        }
        
        dict["items"] = itemsArray
        
        return dict
    }
    
    var restaurantLocation: CLLocationCoordinate2D? {
        // Convert restaurant address to coordinates
        // This is a placeholder - you'll need to implement geocoding
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    var deliveryLocation: CLLocationCoordinate2D? {
        // Convert delivery address to coordinates
        // This is a placeholder - you'll need to implement geocoding
        return CLLocationCoordinate2D(latitude: 37.7833, longitude: -122.4167)
    }
}

struct DeliveryOrderItem: Identifiable {
    let id: String
    let menuItemId: String
    let name: String
    let description: String
    let price: Double
    let quantity: Int
    let totalPrice: Double
    let imageURL: String?
    let specialInstructions: String?
    let customizations: [String: [CustomizationSelection]]
    
    init?(data: [String: Any]) {
        guard let id = data["id"] as? String,
              let menuItemId = data["menuItemId"] as? String,
              let name = data["name"] as? String,
              let description = data["description"] as? String,
              let price = data["price"] as? Double,
              let quantity = data["quantity"] as? Int else {
            return nil
        }
        
        self.id = id
        self.menuItemId = menuItemId
        self.name = name
        self.description = description
        self.price = price
        self.quantity = quantity
        self.totalPrice = data["totalPrice"] as? Double ?? (price * Double(quantity))
        self.imageURL = data["imageURL"] as? String
        self.specialInstructions = data["specialInstructions"] as? String
        
        // Parse customizations
        var customizationsMap: [String: [CustomizationSelection]] = [:]
        if let customizationsData = data["customizations"] as? [String: [[String: Any]]] {
            for (optionId, selections) in customizationsData {
                customizationsMap[optionId] = selections.compactMap { selectionData in
                    guard let optionId = selectionData["optionId"] as? String,
                          let optionName = selectionData["optionName"] as? String,
                          let selectedItemsData = selectionData["selectedItems"] as? [[String: Any]] else {
                        return nil
                    }
                    
                    let selectedItems = selectedItemsData.compactMap { itemData -> SelectedItem? in
                        guard let id = itemData["id"] as? String,
                              let name = itemData["name"] as? String,
                              let price = itemData["price"] as? Double else {
                            return nil
                        }
                        return SelectedItem(id: id, name: name, price: price)
                    }
                    
                    return CustomizationSelection(
                        optionId: optionId,
                        optionName: optionName,
                        selectedItems: selectedItems
                    )
                }
            }
        }
        self.customizations = customizationsMap
    }
} 