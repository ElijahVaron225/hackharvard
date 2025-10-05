
import Foundation
import Supabase
 
final class VideoUploadService {
    
    private let supabase: SupabaseClient
    private let bucketName: String
    
    init(
        supabaseURL: String = "https://ygrolpbmsuhcslizztvy.supabase.co",
        supabaseKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlncm9scGJtc3VoY3NsaXp6dHZ5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTU0NTg1NSwiZXhwIjoyMDc1MTIxODU1fQ.dlmV6q2obd9JIRFX7lzB9s49HrJP0v0I9SzITB2KitI",
        bucketName: String = "user_videos"
    ) {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey
        )
        self.bucketName = bucketName
    }
    
    // MARK: - Public Methods
    
    /// Uploads a video file to Supabase storage
    /// - Parameter fileURL: Local file URL of the video to upload
    /// - Returns: Public URL of the uploaded video
    /// - Throws: Error if upload fails
    func uploadVideo(from fileURL: URL) async throws -> String {
        print("📹 Starting upload from:", fileURL.lastPathComponent)
        
        // Read video data
        let videoData = try Data(contentsOf: fileURL)
        
        // Generate unique filename
        let fileName = generateFileName(from: fileURL)
        
        // Upload to Supabase
        _ = try await supabase.storage
            .from(bucketName)
            .upload(
                fileName,
                data: videoData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "video/mp4",
                    upsert: false
                )
            )
        
        // Get public URL
        let publicURL = try supabase.storage
            .from(bucketName)
            .getPublicURL(path: fileName)
        
        print("✅ Upload successful!")
        print("🔗 Public URL:", publicURL)
        
        return publicURL.absoluteString
    }
    
    // MARK: - Private Helpers
    
    private func generateFileName(from url: URL) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        return "\(timestamp)_\(uuid).mp4"
    }
}
