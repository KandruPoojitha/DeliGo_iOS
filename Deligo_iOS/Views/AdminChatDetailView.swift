import SwiftUI
import FirebaseDatabase

struct AdminChatDetailView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var chatManager: ChatManager
    @State private var messageText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    let thread: ChatThread
    
    init(authViewModel: AuthViewModel, thread: ChatThread) {
        self.authViewModel = authViewModel
        self.thread = thread
        
        // Create a chat manager for the admin
        let userId = authViewModel.currentUserId ?? ""
        let userName = "Admin Support" // Fixed name for admin
        
        _chatManager = StateObject(wrappedValue: ChatManager(
            userId: userId,
            userName: userName,
            isAdmin: true
        ))
    }
    
    var body: some View {
        VStack {
            // Chat header
            HStack {
                VStack(alignment: .leading) {
                    Text(thread.customerName)
                        .font(.headline)
                    Text("ID: \(thread.customerId)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Role: \(thread.userRole)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .padding()
                
                Spacer()
            }
            .background(Color(hexString: "F4A261").opacity(0.2))
            
            // Messages list
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message, isFromCurrentUser: message.senderType == "admin")
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .onChange(of: chatManager.messages) { _, messages in
                    if let lastMessage = messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(Color(hexString: "F4A261"))
                        .padding(10)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Chat with \(thread.customerName) (\(thread.userRole))")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMessages()
            markAsRead()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Message Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadMessages() {
        chatManager.loadMessages(threadId: thread.id)
    }
    
    private func markAsRead() {
        chatManager.markThreadAsRead(threadId: thread.id)
    }
    
    private func sendMessage() {
        guard let userId = authViewModel.currentUserId else {
            alertMessage = "You need to be logged in to respond to customers"
            showingAlert = true
            return
        }
        
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        chatManager.sendMessage(threadId: thread.id, message: message) { success in
            if success {
                messageText = ""
            } else {
                alertMessage = "Failed to send message. Please try again."
                showingAlert = true
            }
        }
    }
}

#Preview {
    // Create a sample thread for preview
    let sampleThread = ChatThread(
        id: "preview",
        customerId: "customer123",
        customerName: "John Doe",
        lastMessage: "Hello, I need help with my order",
        lastMessageTimestamp: Date().timeIntervalSince1970 * 1000,
        unreadCount: 1
    )
    
    return AdminChatDetailView(authViewModel: AuthViewModel(), thread: sampleThread)
} 