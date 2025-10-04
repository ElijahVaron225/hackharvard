import Supabase
import Foundation

//User Type
struct User: Codable {
    let id: String
    let username: String
    let email: String
    let created_at: String
}

class Auth {
    static let shared = Auth()
    private let supabase: SupabaseClient
    private var user: User?
    init(
        supabaseURL: String = "https://ygrolpbmsuhcslizztvy.supabase.co",
        supabaseKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlncm9scGJtc3VoY3NsaXp6dHZ5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTU0NTg1NSwiZXhwIjoyMDc1MTIxODU1fQ.dlmV6q2obd9JIRFX7lzB9s49HrJP0v0I9SzITB2KitI",
    ) {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey
        )
        self.user = nil
    }
    
    func signIn(email: String, password: String) async throws {
        let response = try await supabase.auth.signIn(email: email, password: password)
        print(response)
        self.user = response.user
    }
    
    func signUp(user: User) async throws {
        let response = try await supabase.auth.signUp(email: user.email, password: user.password)

        print(response)
        self.user = response.user

        //Create user in database
        let _ = try await supabase.from("users").insert(user).execute()
    }

    func signOut() async throws {
        let _ = try await supabase.auth.signOut()
        self.user = nil
    }
}