import Foundation
import Combine 

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var loading = false
    @Published var errorMessage: String?
    @Published var launchingPostId: String? = nil

    // Replace with your actual backend URL
    private let baseURL = "https://hackharvard-u5gt.onrender.com" // Update this to your actual backend URL
    private var feedURL: URL {
        URL(string: "\(baseURL)/api/v1/supabase/get-posts")!
    }

    func loadPosts() async {
        guard !loading else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: feedURL)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            guard (200..<300).contains(statusCode) else {
                throw NSError(domain: "HTTP \(statusCode)", code: statusCode)
            }
            
            let decoded = try JSONDecoder().decode([Post].self, from: data)
            posts = decoded
        } catch {
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
            print("Feed error:", error)
        }
    }
    
    func refreshPosts() async {
        await loadPosts()
    }
    
    // MARK: - Experience Launch Logic
    
    func launchExperience(for post: Post) async -> Experience? {
        guard let postId = post.id else {
            print("Error: Post has no ID")
            return nil
        }
        
        // Prevent double-taps/race conditions
        guard launchingPostId != postId else {
            print("Experience already launching for post \(postId)")
            return nil
        }
        
        launchingPostId = postId
        defer { launchingPostId = nil }
        
        // Check if we have a generated image URL from the database
        if let generatedImageURL = post.primaryGeneratedImageURL {
            // Create experience from the generated image URL
            let experience = Experience(
                id: postId,
                skyboxURL: generatedImageURL.absoluteString,
                modelURL: generatedImageURL.absoluteString, // Using same URL for both for now
                artifactName: post.user_scanned_item ?? "Cultural Artifact",
                culture: "Unknown Culture", // Could be enhanced with culture field
                userStory: "Shared cultural artifact"
            )
            print("Using generated image for post \(postId): \(generatedImageURL.absoluteString)")
            return experience
        }
        
        // Fallback to thumbnail URL if available
        if let thumbnailURL = post.thumbnail_url, !thumbnailURL.isEmpty,
           let url = URL(string: thumbnailURL) {
            let experience = Experience(
                id: postId,
                skyboxURL: thumbnailURL,
                modelURL: thumbnailURL,
                artifactName: post.user_scanned_item ?? "Cultural Artifact",
                culture: "Unknown Culture",
                userStory: "Shared cultural artifact"
            )
            print("Using thumbnail as fallback for post \(postId): \(thumbnailURL)")
            return experience
        }
        
        // Last resort: use test experience
        print("No generated image or thumbnail for post \(postId), using test experience")
        return Experience.testExperience
    }
    
    func isLaunching(for post: Post) -> Bool {
        return launchingPostId == post.id
    }
}
