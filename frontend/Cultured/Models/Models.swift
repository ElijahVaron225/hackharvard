import Foundation

struct Experience: Identifiable, Codable {
    let id: String
    let skyboxURL: String
    let modelURL: String
    let artifactName: String
    let culture: String
    let userStory: String
}

struct Post: Codable, Identifiable {
    var id: String?
    var user_id: String
    var thumbnail_url: String?
    var user_scanned_item: String?
    var generated_image: String?
    var likes: Int
    var created_at: Date?

    init(id: String? = nil,
         user_id: String,
         thumbnail_url: String? = nil,
         user_scanned_item: String? = nil,
         generated_image: String? = nil,
         likes: Int = 0,
         created_at: Date? = nil) {
        self.id = id
        self.user_id = user_id
        self.thumbnail_url = thumbnail_url
        self.user_scanned_item = user_scanned_item
        self.generated_image = generated_image
        self.likes = likes
        self.created_at = created_at
    }
}

// Custom decoding for created_at string to Date
extension Post {
    enum CodingKeys: String, CodingKey {
        case id, user_id, thumbnail_url, user_scanned_item, generated_image, likes, created_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        thumbnail_url = try container.decodeIfPresent(String.self, forKey: .thumbnail_url)
        user_scanned_item = try container.decodeIfPresent(String.self, forKey: .user_scanned_item)
        generated_image = try container.decodeIfPresent(String.self, forKey: .generated_image)
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        
        // Handle created_at as either String or Date
        if let dateString = try? container.decode(String.self, forKey: .created_at) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            created_at = formatter.date(from: dateString)
        } else {
            created_at = try container.decodeIfPresent(Date.self, forKey: .created_at)
        }
    }
}

extension Experience {
    static let testExperience = Experience(
        id: "test_001",
        skyboxURL: "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/thumbnails/M3_Photoreal_equirectangular-jpg_wide_open_plaza_in_847306475_455207.jpg",
        modelURL: "https://ygrolpbmsuhcslizztvy.supabase.co/storage/v1/object/public/user_scanned_items/vintage_cannon_3d_model_free.glb",
        artifactName: "Navajo Wedding Basket",
        culture: "Diné (Navajo)",
        userStory: "My grandmother's basket from Monument Valley, 1952"
    )
}
