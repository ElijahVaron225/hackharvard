import SwiftUI

struct FeedList: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.loading {
                        ProgressView("Loading posts...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Failed to load posts")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task {
                                    await viewModel.refreshPosts()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if viewModel.posts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No posts yet")
                                .font(.headline)
                            Text("Be the first to share a cultural artifact!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ForEach(viewModel.posts) { post in
                            FeedPost(post: post)
                            Divider()
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshPosts()
            }
            .navigationTitle("Feed")
            .task {
                await viewModel.loadPosts()
            }
        }
    }
}

#Preview {
    FeedList()
}
