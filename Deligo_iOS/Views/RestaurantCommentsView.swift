import SwiftUI
import FirebaseDatabase

struct RestaurantCommentsView: View {
    let restaurantId: String
    @State private var comments: [RestaurantComment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading comments...")
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Error loading comments")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        loadComments()
                    }
                    .padding()
                    .background(Color(hex: "F4A261"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            } else if comments.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Comments Yet")
                        .font(.headline)
                    Text("Be the first to leave a review for this restaurant!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Restaurant Reviews")
        .onAppear {
            loadComments()
        }
    }
    
    private func loadComments() {
        isLoading = true
        errorMessage = nil
        comments = []
        
        let db = Database.database().reference()
        let commentsRef = db.child("restaurants").child(restaurantId).child("ratingsandcomments").child("comment")
        
        commentsRef.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists() else {
                isLoading = false
                return
            }
            
            var loadedComments: [RestaurantComment] = []
            
            // Create a dispatch group to handle async operations
            let group = DispatchGroup()
            
            for child in snapshot.children {
                guard let commentSnapshot = child as? DataSnapshot else { continue }
                
                let userId = commentSnapshot.key
                guard let comment = commentSnapshot.value as? String, !comment.isEmpty else { continue }
                
                group.enter()
                
                // Get the rating for this user
                let ratingRef = db.child("restaurants").child(restaurantId).child("ratingsandcomments").child("rating").child(userId)
                
                ratingRef.observeSingleEvent(of: .value) { ratingSnapshot in
                    let rating = ratingSnapshot.value as? Int ?? 0
                    
                    // Get the user's name
                    let userRef = db.child("customers").child(userId)
                    
                    userRef.observeSingleEvent(of: .value) { userSnapshot in
                        if let userData = userSnapshot.value as? [String: Any] {
                            // Try to get user's full name from different possible locations
                            var userName = "Anonymous"
                            
                            if let fullName = userData["fullName"] as? String {
                                userName = fullName
                            } else if let userInfo = userData["user_info"] as? [String: Any],
                                      let fullName = userInfo["fullName"] as? String {
                                userName = fullName
                            } else if let firstName = userData["firstName"] as? String,
                                      let lastName = userData["lastName"] as? String {
                                userName = "\(firstName) \(lastName)"
                            } else if let email = userData["email"] as? String {
                                // Use email as a fallback
                                userName = email.components(separatedBy: "@").first ?? email
                            }
                            
                            // Create timestamp (use current time as fallback)
                            let timestamp = (userData["ratingsAndComments"] as? [String: Any])?["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
                            
                            let commentData: [String: Any] = [
                                "userId": userId,
                                "userName": userName,
                                "comment": comment,
                                "rating": rating,
                                "timestamp": timestamp
                            ]
                            
                            let commentObj = RestaurantComment(id: userId, data: commentData)
                            loadedComments.append(commentObj)
                        }
                        
                        group.leave()
                    }
                }
            }
            
            // When all async operations are complete
            group.notify(queue: .main) {
                // Sort comments by timestamp (newest first)
                self.comments = loadedComments.sorted { $0.timestamp > $1.timestamp }
                self.isLoading = false
            }
        } withCancel: { error in
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}

struct CommentRow: View {
    let comment: RestaurantComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comment.userName)
                    .font(.headline)
                Spacer()
                Text(comment.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Star rating
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= comment.rating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            Text(comment.comment)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}



#Preview {
    NavigationView {
        RestaurantCommentsView(restaurantId: "testRestaurantId")
    }
} 
