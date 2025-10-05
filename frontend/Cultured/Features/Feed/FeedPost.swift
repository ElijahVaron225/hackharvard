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
                    Text("User \(post.user_id.prefix(8))") // Show first 8 chars of user_id
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(timeAgoString(from: post.created_at))
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
                
                if let caption = post.caption, !caption.isEmpty {
                    Text("\(Text("User \(post.user_id.prefix(8))").fontWeight(.semibold)) \(caption)")
                } else {
                    Text("\(Text("User \(post.user_id.prefix(8))").fontWeight(.semibold)) Shared a cultural artifact")
                }
                
                if let scannedItems = post.user_scanned_items, !scannedItems.isEmpty {
                    Text("📱 Scanned: \(scannedItems)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(timeAgoString(from: post.created_at))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            .padding(.vertical, 8)
            .padding(.horizontal)
        }
    }
    
    private func timeAgoString(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        guard let date = formatter.date(from: dateString) else {
            return "Unknown time"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
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
        user_scanned_items: "Navajo Basket",
        generated_images: nil,
        likes: 5,
        caption: "My grandmother's traditional basket",
        created_at: "2024-01-15T10:30:00.000000Z"
    ))
}
