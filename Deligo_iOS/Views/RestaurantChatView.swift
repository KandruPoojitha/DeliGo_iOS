import SwiftUI
import FirebaseDatabase

struct RestaurantChatView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    // These parameters are used for order-specific chat
    var orderId: String
    var customerId: String
    var customerName: String
    
    // This flag distinguishes between admin support and customer order chat
    private var isAdminSupportChat: Bool {
        return orderId == "admin_support" && customerId == "admin"
    }
    
    // For admin support chat, we'll use a ChatManager
    @StateObject private var chatManager: ChatManager
    
    // For direct order chat, we'll use database reference
    private let database = Database.database().reference()
    
    init(orderId: String, customerId: String, customerName: String, authViewModel: AuthViewModel) {
        self.orderId = orderId
        self.customerId = customerId
        self.customerName = customerName
        self.authViewModel = authViewModel
        
        // Initialize chat manager for admin support
        let userId = authViewModel.currentUserId ?? ""
        _chatManager = StateObject(wrappedValue: ChatManager(
            userId: userId, 
            userName: authViewModel.fullName ?? "Restaurant",
            isAdmin: false
        ))
    }
    
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
                
                Text(isAdminSupportChat ? "Admin Support" : customerName)
                    .font(.headline)
                    .padding(.leading, 8)
                
                Spacer()
                
                if !isAdminSupportChat {
                    Text("Order #\(orderId.prefix(8))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            if isLoading {
                Spacer()
                ProgressView("Loading conversation...")
                Spacer()
            } else if isAdminSupportChat ? chatManager.messages.isEmpty : messages.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No messages yet")
                        .font(.headline)
                    Text(isAdminSupportChat ? "Start a conversation with admin support" : "Start a conversation with the customer")
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
                            if isAdminSupportChat {
                                // Admin support messages
                                ForEach(chatManager.messages) { message in
                                    MessageBubble(message: message, isFromCurrentUser: message.senderType == "restaurant")
                                        .id(message.id)
                                }
                            } else {
                                // Order-specific customer messages
                                ForEach(messages) { message in
                                    MessageBubble(message: message, isFromCurrentUser: message.senderType == "restaurant")
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onChange(of: isAdminSupportChat ? chatManager.messages : messages) { _, newMessages in
                        if let lastMessage = newMessages.last {
                            withAnimation {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastMessage = (isAdminSupportChat ? chatManager.messages.last : messages.last) {
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
            // Ensure user data is loaded
            authViewModel.loadUserProfile()
            
            // Load the appropriate messages
            if isAdminSupportChat {
                loadAdminSupportMessages()
            } else {
                loadOrderMessages()
            }
            
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
    
    // Load messages for admin support chat
    private func loadAdminSupportMessages() {
        isLoading = true
        let threadId = chatManager.getThreadId()
        chatManager.loadMessages(threadId: threadId)
        
        // Add a delay to ensure messages are loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
        }
    }
    
    // Load messages for order-specific chat
    private func loadOrderMessages() {
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
    
    // Send message to the appropriate channel
    private func sendMessage() {
        let restaurantId = authViewModel.currentUserId ?? "restaurant_unknown"
        let restaurantName = authViewModel.fullName ?? "Restaurant"
        let messageContent = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !messageContent.isEmpty else {
            print("Failed to send message: empty message")
            return
        }
        
        if isAdminSupportChat {
            // Send to admin support
            let threadId = chatManager.getThreadId()
            chatManager.sendMessage(threadId: threadId, message: messageContent, userRole: "Restaurant") { success in
                DispatchQueue.main.async {
                    if success {
                        self.messageText = ""
                    } else {
                        self.alertMessage = "Failed to send message. Please try again."
                        self.showAlert = true
                    }
                }
            }
        } else {
            // Send to customer order chat
            print("Sending message from restaurant \(restaurantName) to order \(orderId)")
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
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error sending message: \(error.localizedDescription)")
                        self.alertMessage = "Failed to send message: \(error.localizedDescription)"
                        self.showAlert = true
                    } else {
                        print("Message sent successfully!")
                        self.messageText = ""
                    }
                }
            }
        }
    }
}

struct RestaurantMessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.senderName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(message.message)
                    .padding(10)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(10)
                
                Text(message.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !isFromCurrentUser { Spacer() }
        }
    }
}

struct RestaurantChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RestaurantChatView(orderId: "admin_support", customerId: "admin", customerName: "Admin", authViewModel: AuthViewModel())
        }
    }
} 
