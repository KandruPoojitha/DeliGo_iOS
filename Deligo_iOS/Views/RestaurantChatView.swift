import SwiftUI
import FirebaseDatabase

struct RestaurantChatView: View {
    let orderId: String
    let customerId: String
    let customerName: String
    @ObservedObject var authViewModel: AuthViewModel
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    private let database = Database.database().reference()
    
    var body: some View {
        VStack {
            // Chat header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(customerName)
                    .font(.headline)
                    .padding(.leading, 8)
                
                Spacer()
                
                Text("Order #\(orderId.prefix(8))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
            
            if isLoading {
                Spacer()
                ProgressView("Loading conversation...")
                Spacer()
            } else if messages.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No messages yet")
                        .font(.headline)
                    Text("Start a conversation with the customer")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                // Messages list
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                MessageBubble(message: message, isFromCurrentUser: message.senderType == "restaurant")
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onChange(of: messages) { _, newMessages in
                        if let lastMessage = newMessages.last {
                            withAnimation {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastMessage = messages.last {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : Color(hex: "F4A261"))
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.leading, 8)
            }
            .padding()
        }
        .onAppear {
            loadMessages()
            // Ensure user data is loaded
            authViewModel.loadUserProfile()
            
            // Print debug info
            print("AUTH INFO - UID: \(authViewModel.currentUserId ?? "nil"), Name: \(authViewModel.fullName ?? "nil")")
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Message Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadMessages() {
        isLoading = true
        
        // Reference to the messages for this order
        let messagesRef = database.child("orders").child(orderId).child("messages")
        
        // Listen for messages
        messagesRef.observe(.value) { snapshot in
            var newMessages: [ChatMessage] = []
            
            for child in snapshot.children {
                guard let messageSnapshot = child as? DataSnapshot,
                      let messageData = messageSnapshot.value as? [String: Any] else { continue }
                
                let message = ChatMessage(id: messageSnapshot.key, data: messageData)
                newMessages.append(message)
            }
            
            // Sort messages by timestamp
            newMessages.sort { $0.timestamp < $1.timestamp }
            
            DispatchQueue.main.async {
                self.messages = newMessages
                self.isLoading = false
            }
        }
    }
    
    private func sendMessage() {
        let restaurantId = authViewModel.currentUserId ?? "restaurant_unknown"
        let restaurantName = authViewModel.fullName ?? "Restaurant"
        let messageContent = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !messageContent.isEmpty else {
            print("Failed to send message: empty message")
            return
        }
        
        print("Sending message from restaurant \(restaurantName) to order \(orderId)")
        print("RestaurantId: \(restaurantId)")
        print("MessageText: \(messageContent)")
        
        let messagesRef = database.child("orders").child(orderId).child("messages")
        let newMessageRef = messagesRef.childByAutoId()
        
        let message = [
            "senderId": restaurantId,
            "senderName": restaurantName,
            "senderType": "restaurant",
            "message": messageContent,
            "timestamp": ServerValue.timestamp(),
            "isRead": false
        ] as [String: Any]
        
        print("Message data: \(message)")
        
        newMessageRef.setValue(message) { error, _ in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to send message: \(error.localizedDescription)"
                    self.showAlert = true
                }
            } else {
                print("Message sent successfully!")
                // Clear the input field
                DispatchQueue.main.async {
                    self.messageText = ""
                }
            }
        }
    }
}

#Preview {
    RestaurantChatView(
        orderId: "order123", 
        customerId: "customer123",
        customerName: "Sample Customer",
        authViewModel: AuthViewModel()
    )
} 