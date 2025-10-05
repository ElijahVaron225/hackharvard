//
    // Project: InstagramRecreation2
    //  File: FeedPost.swift
    //  Created by Noah Carpenter
    //  🐱 Follow me on YouTube! 🎥
    //  https://www.youtube.com/@NoahDoesCoding97
    //  Like and Subscribe for coding tutorials and fun! 💻✨
    //  Fun Fact: Cats have five toes on their front paws, but only four on their back paws! 🐾
    //  Dream Big, Code Bigger
    

import SwiftUI

struct FeedPost: View {
    var username: String
    var location: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0){
            HStack{
                Circle()
                    .fill(.gray.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "person.fill"))
                VStack(alignment: .leading, spacing: 2){
                    Text(username)
                        .font(.subheadline)
                    if let location {
                        Text(location)
                            .font(.caption)
                    }
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ZStack{
                Rectangle()
                    .fill(.gray.opacity(0.25))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(Image("post").resizable())
                    .font(.system(size: 90))
            }
            
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
            
            VStack(alignment: .leading, spacing: 8){
                Text("Liked by \(Text("swiftdev").fontWeight(.semibold)) and others")
                Text("\(Text(username).fontWeight(.semibold))  This is a placeholder caption to mimic Instagram's layout.")
                Text("View all 42 comments").foregroundStyle(.secondary)
                Text("2 hours ago").font(.caption2).foregroundStyle(.secondary)
            }
            .font(.footnote)
            .padding(.vertical, 8)
            .padding(.horizontal)
            
        }
        
    }
}

#Preview {
    FeedPost(username: "Placeholder")
}
