import Foundation

class CreatePostManager {
    static let shared = CreatePostManager()
    private var post: Post?
    
    private init() {}

    func createPost() async -> Void {
        do {
            let currentUser = Auth.shared.user
            print("Current user: \(currentUser?.id)")

            var newPost = Post(id: "", user_id: currentUser?.id ?? "", thumbnail_url: "", user_scanned_items: "", generated_images: "", likes: 0, caption: nil, created_at: "")

            let url = URL(string: "https://hackharvard-u5gt.onrender.com/api/v1/supabase/create-post")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(newPost)

            let (data, response) = try await URLSession.shared.data(for: request)

            // Parse the JSON response
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let postId = json?["post_id"] as? String {
                newPost = Post(id: postId, user_id: newPost.user_id, thumbnail_url: newPost.thumbnail_url, user_scanned_items: newPost.user_scanned_items, generated_images: newPost.generated_images, likes: 0, caption: nil, created_at: "")
            }
            
            self.post = newPost
            print("Response: \(response)")
            print("Data: \(String(data: data, encoding: .utf8) ?? "No data")")
        } catch {
            print("Error: \(error)")
        }
    }
}
