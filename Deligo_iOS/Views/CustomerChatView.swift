import SwiftUI
import FirebaseDatabase

struct CustomerChatView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var chatManager: ChatManager
    @State private var messageText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        
        // Create a chat manager for the customer
        let userId = authViewModel.currentUserId ?? ""
        let userName = authViewModel.fullName ?? "Customer"
        
        _chatManager = StateObject(wrappedValue: ChatManager(
            userId: userId,
            userName: userName,
            isAdmin: false
        ))
    }
    
    var body: some View {
        VStack {
            // Chat header
            HStack {
                Text("Customer Support")
                    .font(.headline)
                    .padding()
                
                Spacer()
            }
            .background(Color(hex: "F4A261").opacity(0.2))
            
            // Messages list
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message, isFromCurrentUser: message.senderType == "customer")
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
                        .foregroundColor(Color(hex: "F4A261"))
                        .padding(10)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Support Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMessages()
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
        guard let userId = authViewModel.currentUserId else {
            alertMessage = "You need to be logged in to chat with support"
            showingAlert = true
            return
        }
        
        let threadId = chatManager.getThreadId()
        chatManager.loadMessages(threadId: threadId)
    }
    
    private func sendMessage() {
        guard let userId = authViewModel.currentUserId else {
            alertMessage = "You need to be logged in to chat with support"
            showingAlert = true
            return
        }
        
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        let threadId = chatManager.getThreadId()
        chatManager.sendMessage(threadId: threadId, message: message) { success in
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
    CustomerChatView(authViewModel: AuthViewModel())
} 