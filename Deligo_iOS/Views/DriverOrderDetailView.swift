import SwiftUI
import GoogleMaps

struct DriverOrderDetailView: View {
    let order: DeliveryOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Order ID and Total
            HStack {
                Text("Order #\(order.id.prefix(8))")
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", order.total))")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            // Restaurant Info
            Text("From: \(order.restaurantName ?? "Restaurant")")
                .font(.subheadline)
            Text(order.address.streetAddress)
                .font(.caption)
                .foregroundColor(.gray)
            
            // Delivery Address
            VStack(alignment: .leading, spacing: 4) {
                Text("To:")
                    .foregroundColor(.gray)
                Text(order.address.formattedAddress)
                    .font(.subheadline)
            }
            
            // Order Items
            VStack(alignment: .leading, spacing: 8) {
                Text("Order Items")
                    .font(.headline)
                    .padding(.top, 4)
                
                ForEach(order.items) { item in
                    HStack {
                        Text("\(item.quantity)x")
                            .foregroundColor(.gray)
                        Text(item.name)
                        if let specialInstructions = item.specialInstructions, !specialInstructions.isEmpty {
                            Text("(\(specialInstructions))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("$\(String(format: "%.2f", item.totalPrice))")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Price Breakdown
            VStack(spacing: 4) {
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text("$\(String(format: "%.2f", order.subtotal))")
                }
                HStack {
                    Text("Delivery Fee")
                    Spacer()
                    Text("$\(String(format: "%.2f", order.deliveryFee))")
                }
                if order.tipAmount > 0 {
                    HStack {
                        Text("Tip")
                        Spacer()
                        Text("$\(String(format: "%.2f", order.tipAmount))")
                    }
                }
                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(String(format: "%.2f", order.total))")
                        .fontWeight(.bold)
                }
            }
            .padding(.vertical, 8)
            
            Spacer()
            
            // Status information
            HStack {
                Text("Status:")
                    .fontWeight(.semibold)
                Text(order.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor(for: order.status))
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 4)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending": return .orange
        case "accepted": return .blue
        case "preparing": return .orange
        case "ready_for_pickup": return .purple
        case "picked_up": return .purple
        case "delivering", "on_the_way": return .green
        case "delivered", "completed": return .green
        case "cancelled": return .red
        default: return .gray
        }
    }
}

#Preview {
    // Sample order for preview
    let sampleOrder = DeliveryOrder(id: "0D82B4DB", data: [
        "createdAt": TimeInterval(Date().timeIntervalSince1970),
        "deliveryFee": 5.00,
        "total": 41.27,
        "subtotal": 35.27,
        "tipAmount": 1.00,
        "restaurantName": "McDonald's",
        "address": [
            "streetAddress": "123 Main St, Montreal",
            "formattedAddress": "5785 Upper Lachine Road, Montreal, QC, Canada, Unit 3"
        ],
        "items": [
            ["id": "1", "name": "Big Mac", "price": 15.99, "quantity": 2, "specialInstructions": "No pickles"],
            ["id": "2", "name": "French Fries", "price": 3.29, "quantity": 1]
        ]
    ])
    
    DriverOrderDetailView(order: sampleOrder!)
        .padding()
        .background(Color.gray.opacity(0.1))
} 
