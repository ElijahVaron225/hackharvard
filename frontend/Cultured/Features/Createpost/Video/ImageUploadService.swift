import Foundation
import Supabase
import UIKit

final class ImageUploadService {
    private let supabase: SupabaseClient
    private let bucketName: String
    
    init(
        supabaseURL: String = "https://ygrolpbmsuhcslizztvy.supabase.co",
        supabaseKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlncm9scGJtc3VoY3NsaXp6dHZ5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTU0NTg1NSwiZXhwIjoyMDc1MTIxODU1fQ.dlmV6q2obd9JIRFX7lzB9s49HrJP0v0I9SzITB2KitI",
        bucketName: String = "user_images"
    ) {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey
        )
        self.bucketName = bucketName
    }
    
    /// Uploads a JPEG image to Supabase storage and returns a public URL.
    func uploadImage(_ image: UIImage) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "ImageUploadService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image"])
        }
        let fileName = generateFileName()
        _ = try await supabase.storage
            .from(bucketName)
            .upload(
                fileName,
                data: jpegData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )
        let publicURL = try supabase.storage
            .from(bucketName)
            .getPublicURL(path: fileName)
        return publicURL.absoluteString
    }
    
    private func generateFileName() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        return "\(timestamp)_\(uuid).jpg"
    }
}


