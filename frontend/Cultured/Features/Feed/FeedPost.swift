import SwiftUI

struct FeedPost: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0){
            // Header with user info
            HStack{
                Circle()
                    .fill(.gray.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "person.fill"))
                VStack(alignment: .leading, spacing: 2){
                    Text(username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(timeAgoString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Main content image
            ZStack{
                Rectangle()
                    .fill(.gray.opacity(0.25))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                
                if let thumbnailURL = post.thumbnail_url, !thumbnailURL.isEmpty {
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
            }
            .clipped()
            
            // Action buttons
            HStack{
                HStack(spacing: 16){
                    Image(systemName: "heart")
                    Image(systemName: "bubble.right")
                    Image(systemName: "paperplane")
                }
                .font(.title2)
                Spacer()
                Image(systemName: "bookmark")
                    .font(.title2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            
            // Caption and metadata
            VStack(alignment: .leading, spacing: 8){
                if post.likes > 0 {
                    Text("Liked by \(Text("\(post.likes) people").fontWeight(.semibold))")
                }
                
                if let caption = post.user_scanned_item, !caption.isEmpty {
                    Text("\(Text(username).fontWeight(.semibold)) Shared: \(caption)")
                } else {
                    Text("\(Text(username).fontWeight(.semibold)) Shared a cultural artifact")
                }
                
                Text(timeAgoString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            .padding(.vertical, 8)
            .padding(.horizontal)
        }
    }
    
    private var username: String {
        // Try to get username from Auth, fallback to user_id
        if let user = Auth.shared.user {
            return user.username
        } else {
            return "User \(String(post.user_id.suffix(8)))"
        }
    }
    
    private var timeAgoString: String {
        guard let created_at = post.created_at else {
            return "Just now"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(created_at)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    FeedPost(post: Post(
        id: "preview-1",
        user_id: "user-123",
        thumbnail_url: nil,
        user_scanned_item: "Navajo Basket",
        generated_image: nil,
        likes: 5,
        created_at: Date()
    ))
}
