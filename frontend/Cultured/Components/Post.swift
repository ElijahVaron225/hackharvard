//
    // Project: InstagramRecreation2
    //  File: Post.swift
    //  Created by Noah Carpenter
    //  🐱 Follow me on YouTube! 🎥
    //  https://www.youtube.com/@NoahDoesCoding97
    //  Like and Subscribe for coding tutorials and fun! 💻✨
    //  Fun Fact: Cats have five toes on their front paws, but only four on their back paws! 🐾
    //  Dream Big, Code Bigger
    
import SwiftUI
import Foundation

struct Post: Identifiable {
    let id = UUID()
    let username: String
    let location: String?
    let imageName: String?   // replace with real asset names later
    let likeCount: Int
    let caption: String
}

let demoPosts: [Post] = [
    .init(username: "Noah", location: "The Moon", imageName: nil, likeCount: 123, caption: "Ship it 🚀"),
    .init(username: "swiftdev", location: nil, imageName: nil, likeCount: 42, caption: "Stacks on stacks")
]

struct FeedListWithData: View {
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(demoPosts) { post in
                FeedPost(username: post.username, location: post.location)
                Divider()
            }
        }
    }
}

#Preview {
    FeedListWithData()
}
