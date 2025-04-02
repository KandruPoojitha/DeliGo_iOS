import SwiftUI

struct AdminOrderManagementView: View {
    @StateObject private var viewModel = AdminOrderManagementViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading orders...")
            } else {
                List {
                    ForEach(viewModel.orders) { order in
                        VStack(alignment: .leading, spacing: 8) {
                            // Order ID and Status
                            HStack {
                                Text("Order #\(order.id.prefix(8))")
                                    .font(.headline)
                                Spacer()
                                Text(order.orderStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: viewModel.statusColor(for: order.orderStatus)))
                                    .cornerRadius(8)
                            }
                            
                            // Restaurant
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.gray)
                                Text("Restaurant: \(order.restaurantName)")
                                    .font(.subheadline)
                            }
                            
                            // Customer
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.gray)
                                Text("Customer: \(order.customerName)")
                                    .font(.subheadline)
                            }
                            
                            // Driver
                            HStack {
                                Image(systemName: "car")
                                    .foregroundColor(.gray)
                                Text("Driver: \(order.driverName ?? "Not Assigned")")
                                    .font(.subheadline)
                            }
                            
                            // Order Items
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Items:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                ForEach(order.items) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("\(item.quantity)x")
                                                .foregroundColor(.gray)
                                            Text(item.name)
                                            Spacer()
                                            Text("$\(String(format: "%.2f", item.price * Double(item.quantity)))")
                                                .foregroundColor(Color(hex: "F4A261"))
                                        }
                                        
                                        if let instructions = item.specialInstructions, !instructions.isEmpty {
                                            Text("Special Instructions: \(instructions)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        if !item.formattedCustomizations.isEmpty {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Customizations:")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                
                                                ForEach(item.formattedCustomizations, id: \.self) { customization in
                                                    Text(customization)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .padding(.leading, 8)
                                                }
                                            }
                                            .padding(.top, 2)
                                        }
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                            .padding(.top, 4)
                            
                            Divider()
                            
                            // Total and Date
                            HStack {
                                Text("Total:")
                                    .fontWeight(.medium)
                                Text("$\(String(format: "%.2f", order.total))")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "F4A261"))
                                Spacer()
                                Text(order.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    viewModel.loadOrders()
                }
            }
        }
        .navigationTitle("Order Management")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadOrders()
        }
    }
} 