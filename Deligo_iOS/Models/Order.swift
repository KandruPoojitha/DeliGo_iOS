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

struct ScheduledOrder: Identifiable {
    let id: String
    let userId: String
    let restaurantId: String
    let items: [DeliveryOrderItem]
    let subtotal: Double
    let tipAmount: Double
    let deliveryFee: Double
    let total: Double
    let deliveryOption: String
    let paymentMethod: String
    let status: String
    let scheduledFor: TimeInterval  // Timestamp for when the order should be processed
    let orderStatus: String
    let createdAt: TimeInterval
    let address: DeliveryAddress
    var driverId: String?
    var driverName: String?
    
    init?(id: String, data: [String: Any]) {
        self.id = id
        
        guard let userId = data["userId"] as? String,
              let restaurantId = data["restaurantId"] as? String,
              let subtotal = data["subtotal"] as? Double,
              let total = data["total"] as? Double,
              let deliveryOption = data["deliveryOption"] as? String,
              let paymentMethod = data["paymentMethod"] as? String,
              let status = data["status"] as? String,
              let scheduledFor = data["scheduledFor"] as? TimeInterval else {
            print("Failed to initialize ScheduledOrder - Missing required fields")
            return nil
        }
        
        self.userId = userId
        self.restaurantId = restaurantId
        self.subtotal = subtotal
        self.tipAmount = data["tipAmount"] as? Double ?? 0.0
        self.deliveryFee = data["deliveryFee"] as? Double ?? 0.0
        self.total = total
        self.deliveryOption = deliveryOption
        self.paymentMethod = paymentMethod
        self.status = status
        self.scheduledFor = scheduledFor
        self.orderStatus = data["order_status"] as? String ?? status
        self.createdAt = data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
        self.driverId = data["driverId"] as? String
        self.driverName = data["driverName"] as? String
        
        // Parse order items
        var orderItems: [DeliveryOrderItem] = []
        if let itemsData = data["items"] as? [[String: Any]] {
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
    }
    
    // Convert to dictionary format for Firebase
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "restaurantId": restaurantId,
            "subtotal": subtotal,
            "tipAmount": tipAmount,
            "deliveryFee": deliveryFee,
            "total": total,
            "deliveryOption": deliveryOption,
            "paymentMethod": paymentMethod,
            "status": status,
            "scheduledFor": scheduledFor,
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
}

// Add these extensions to make DeliveryOrderItem and CustomizationSelection conform to Codable
extension DeliveryOrderItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case menuItemId
        case name
        case description
        case price
        case quantity
        case totalPrice
        case imageURL
        case specialInstructions
        case customizations
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        menuItemId = try container.decode(String.self, forKey: .menuItemId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Double.self, forKey: .price)
        quantity = try container.decode(Int.self, forKey: .quantity)
        totalPrice = try container.decode(Double.self, forKey: .totalPrice)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        specialInstructions = try container.decodeIfPresent(String.self, forKey: .specialInstructions)
        customizations = try container.decode([String: [CustomizationSelection]].self, forKey: .customizations)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(menuItemId, forKey: .menuItemId)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(totalPrice, forKey: .totalPrice)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(specialInstructions, forKey: .specialInstructions)
        try container.encode(customizations, forKey: .customizations)
    }
}

// Now implement Codable for ScheduledOrder
extension ScheduledOrder: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case restaurantId
        case items
        case subtotal
        case tipAmount
        case deliveryFee
        case total
        case deliveryOption
        case paymentMethod
        case status
        case scheduledFor
        case orderStatus
        case createdAt
        case address
        case driverId
        case driverName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        restaurantId = try container.decode(String.self, forKey: .restaurantId)
        items = try container.decode([DeliveryOrderItem].self, forKey: .items)
        subtotal = try container.decode(Double.self, forKey: .subtotal)
        tipAmount = try container.decode(Double.self, forKey: .tipAmount)
        deliveryFee = try container.decode(Double.self, forKey: .deliveryFee)
        total = try container.decode(Double.self, forKey: .total)
        deliveryOption = try container.decode(String.self, forKey: .deliveryOption)
        paymentMethod = try container.decode(String.self, forKey: .paymentMethod)
        status = try container.decode(String.self, forKey: .status)
        scheduledFor = try container.decode(TimeInterval.self, forKey: .scheduledFor)
        orderStatus = try container.decode(String.self, forKey: .orderStatus)
        createdAt = try container.decode(TimeInterval.self, forKey: .createdAt)
        address = try container.decode(DeliveryAddress.self, forKey: .address)
        driverId = try container.decodeIfPresent(String.self, forKey: .driverId)
        driverName = try container.decodeIfPresent(String.self, forKey: .driverName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(restaurantId, forKey: .restaurantId)
        try container.encode(items, forKey: .items)
        try container.encode(subtotal, forKey: .subtotal)
        try container.encode(tipAmount, forKey: .tipAmount)
        try container.encode(deliveryFee, forKey: .deliveryFee)
        try container.encode(total, forKey: .total)
        try container.encode(deliveryOption, forKey: .deliveryOption)
        try container.encode(paymentMethod, forKey: .paymentMethod)
        try container.encode(status, forKey: .status)
        try container.encode(scheduledFor, forKey: .scheduledFor)
        try container.encode(orderStatus, forKey: .orderStatus)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(address, forKey: .address)
        try container.encodeIfPresent(driverId, forKey: .driverId)
        try container.encodeIfPresent(driverName, forKey: .driverName)
    }
} 