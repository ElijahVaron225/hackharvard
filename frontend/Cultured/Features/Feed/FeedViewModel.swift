import Foundation
import Combine 

struct FeedItem: Identifiable, Decodable {
    let id: String
    let username: String
    let imageUrl: URL
    let location: String?
    let aspectRatio: Double?
}

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var items: [FeedItem] = []
    @Published var loading = false
    @Published var errorMessage: String?

    // TODO: replace with your real endpoint
    private let feedURL = URL(string: "https://api/v1/")!

    func load() async {
        guard !loading else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }

        do {
            let (data, resp) = try await URLSession.shared.data(from: feedURL)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else {
                throw NSError(domain: "HTTP \(code)", code: code)
            }
            let decoded = try JSONDecoder().decode([FeedItem].self, from: data) // or FeedResponse if your API wraps it
            items = decoded
        } catch {
            errorMessage = "Failed to load feed"
            print("Feed error:", error)
        }
    }
}
