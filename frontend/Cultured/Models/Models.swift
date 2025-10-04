import Foundation

struct Experience: Identifiable, Codable {
    let id: String
    let skyboxURL: String
    let modelURL: String
    let artifactName: String
    let culture: String
    let userStory: String
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
