import SwiftUI

struct FeedList: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        LazyVStack(spacing: 0) {
            if viewModel.loading {
                ProgressView("Loading posts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.primary.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("Connection Issue")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.text)
                        
                        Text("Unable to load posts from server")
                            .font(.body)
                            .foregroundColor(.text.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("Try Again") {
                        Task {
                            await viewModel.refreshPosts()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
            } else if viewModel.posts.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.primary.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("No Posts Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.text)
                        
                        Text("Be the first to share a cultural artifact!")
                            .font(.body)
                            .foregroundColor(.text.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
            } else {
                ForEach(viewModel.posts) { post in
                    FeedPost(post: post)
                    Divider()
                }
            }
        }
        .refreshable {
            await viewModel.refreshPosts()
        }
        .task {
            await viewModel.loadPosts()
        }
    }
}

#Preview {
    FeedList()
}
