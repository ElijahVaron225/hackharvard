import Foundation
import Combine

class CreatePostManager: ObservableObject {
    static let shared = CreatePostManager()
    @Published private(set) var post: Post?
    
    private init() {}

    func createPost() async throws {
        guard let userID = Auth.shared.userID else {
            throw CreatePostError.noUser
        }

        let newPost = Post(
            user_id: userID,
            thumbnail_url: nil,
            user_scanned_item: nil,
            generated_images: nil,
            likes: 0,
            created_at: Date()
        )

        let url = URL(string: "http://127.0.0.1:8080/api/v1/supabase/create-post")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(newPost)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CreatePostError.invalidResponse
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                print("HTTP \(httpResponse.statusCode): \(errorBody)")
                throw CreatePostError.serverError(httpResponse.statusCode, errorBody)
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let postId = json?["post_id"] as? String {
                var updatedPost = newPost
                updatedPost.id = postId
                
                await MainActor.run {
                    self.post = updatedPost
                }
            }
            
            print("Post created successfully: \(String(data: data, encoding: .utf8) ?? "No data")")
            
        } catch {
            print("CreatePost error: \(error)")
            throw error
        }
    }
}

enum CreatePostError: LocalizedError {
    case noUser
    case invalidResponse
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .noUser:
            return "No user logged in"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        }
    }
}
