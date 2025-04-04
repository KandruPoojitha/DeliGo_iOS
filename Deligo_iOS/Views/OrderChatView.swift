import SwiftUI
import FirebaseDatabase

struct OrderChatView: View {
    let orderId: String
    let chatType: String // "restaurant_customer" or "driver_customer"
    let recipientId: String
    let recipientName: String
    @ObservedObject var authViewModel: AuthViewModel
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = true
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
                
                Text(recipientName)
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
                    Text("Start a conversation with \(chatType == "driver_customer" ? "the customer" : "the restaurant")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                // Messages list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == authViewModel.currentUserId
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
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
        }
        .navigationBarHidden(true)
    }
    
    private func loadMessages() {
        isLoading = true
        
        // Reference to the messages for this order
        let messagesRef = database.child("orders").child(orderId).child(chatType == "driver_customer" ? "driver_customer_messages" : "messages")
        
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
        guard let userId = authViewModel.currentUserId,
              let userName = authViewModel.fullName,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let messagesRef = database.child("orders").child(orderId).child(chatType == "driver_customer" ? "driver_customer_messages" : "messages")
        let newMessageRef = messagesRef.childByAutoId()
        
        let message = [
            "senderId": userId,
            "senderName": userName,
            "senderType": chatType == "driver_customer" ? "driver" : "customer",
            "message": messageText.trimmingCharacters(in: .whitespacesAndNewlines),
            "timestamp": ServerValue.timestamp()
        ] as [String: Any]
        
        newMessageRef.setValue(message) { error, _ in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            } else {
                // Clear the input field
                DispatchQueue.main.async {
                    self.messageText = ""
                }
            }
        }
    }
}

#Preview {
    OrderChatView(
        orderId: "order123", 
        chatType: "restaurant_customer",
        recipientId: "customer123",
        recipientName: "Sample Customer",
        authViewModel: AuthViewModel()
    )
} 