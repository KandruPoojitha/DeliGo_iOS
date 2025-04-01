import SwiftUI
import MapKit

struct DriverOrderDetailView: View {
    let order: DriverOrder
    let onAccept: () -> Void
    let onReject: () -> Void
    
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
            Text("From: \(order.restaurantName)")
                .font(.subheadline)
            if !order.restaurantAddress.isEmpty {
                Text(order.restaurantAddress)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Delivery Address
            VStack(alignment: .leading, spacing: 4) {
                Text("To:")
                    .foregroundColor(.gray)
                Text(order.deliveryAddress)
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
                        if !item.specialInstructions.isEmpty {
                            Text("(\(item.specialInstructions))")
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
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: onReject) {
                    Text("REJECT")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
                
                Button(action: onAccept) {
                    Text("ACCEPT ORDER")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 4)
    }
}

#Preview {
    // Sample order for preview
    let sampleOrder = DriverOrder(id: "0D82B4DB", data: [
        "createdAt": TimeInterval(Date().timeIntervalSince1970),
        "deliveryFee": 5.00,
        "total": 41.27,
        "subtotal": 35.27,
        "tipAmount": 1.00,
        "restaurantName": "McDonald's",
        "restaurantAddress": "123 Main St, Montreal",
        "deliveryAddress": "5785 Upper Lachine Road, Montreal, QC, Canada, Unit 3",
        "items": [
            ["id": "1", "name": "Big Mac", "price": 15.99, "quantity": 2, "specialInstructions": "No pickles"],
            ["id": "2", "name": "French Fries", "price": 3.29, "quantity": 1]
        ]
    ])
    
    return DriverOrderDetailView(
        order: sampleOrder,
        onAccept: {},
        onReject: {}
    )
    .padding()
    .background(Color.gray.opacity(0.1))
} 