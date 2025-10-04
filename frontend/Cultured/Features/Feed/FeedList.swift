//
    // Project: InstagramRecreation2
    //  File: FeedList.swift
    //  Created by Noah Carpenter
    //  🐱 Follow me on YouTube! 🎥
    //  https://www.youtube.com/@NoahDoesCoding97
    //  Like and Subscribe for coding tutorials and fun! 💻✨
    //  Fun Fact: Cats have five toes on their front paws, but only four on their back paws! 🐾
    //  Dream Big, Code Bigger
    

import SwiftUI

struct FeedList: View {
    var body: some View {
        LazyVStack(spacing:0){
            ForEach(0..<6){ idx in
                FeedPost(username: "user_\(idx)", location: idx % 2 == 0 ? "Cupertino, CA" : nil)
                Divider()
            }
        }
    }
}

#Preview {
    FeedList()
}
