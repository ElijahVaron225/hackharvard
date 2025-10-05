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
        
        // Check if we already have a generated image
        if let generatedImage = post.generated_image, !generatedImage.isEmpty {
            // Create experience from existing generated image
            let experience = Experience(
                id: postId,
                skyboxURL: generatedImage,
                modelURL: generatedImage, // Using same URL for both for now
                artifactName: post.user_scanned_item ?? "Cultural Artifact",
                culture: "Unknown Culture", // Could be enhanced with culture field
                userStory: "Shared cultural artifact"
            )
            return experience
        }
        
        // If no generated image, use the test experience for now
        // In a real implementation, this would call the generation API
        print("No generated image for post \(postId), using test experience")
        return Experience.testExperience
    }
    
    func isLaunching(for post: Post) -> Bool {
        return launchingPostId == post.id
    }
}
