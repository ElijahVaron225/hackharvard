import Foundation
import Combine 

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var loading = false
    @Published var errorMessage: String?

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
}
