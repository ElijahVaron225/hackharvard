import Supabase
import Foundation

extension Date {
    var iso8601StringUTC: String {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: self)
    }
}


// User Type (public table row)
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
        supabaseKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlncm9scGJtc3VoY3NsaXp6dHZ5Iiwicm9zZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTU0NTg1NSwiZXhwIjoyMDc1MTIxODU1fQ.dlmV6q2obd9JIRFX7lzB9s49HrJP0v0I9SzITB2KitI"
    ) {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey
        )
        self.user = nil
    }

    // Sign in with email/password, then load the profile row into self.user
    func signIn(email: String, password: String) async throws {
        let response = try await supabase.auth.signIn(email: email, password: password) // Auth call [web:88]
        print(response)

        // Fetch the matching public users row by auth user id (uuid string)
        let authUserId = response.user.id.uuidString  // current SDK User.id is UUID [web:88][web:99]
        let fetched: User = try await supabase
            .from("users")
            .select()
            .eq("id", value: authUserId)
            .single()
            .execute()
            .value                                           // return single row [web:115]

        self.user = fetched
    }

    // Sign up with credentials passed via the given user.email and an extra password parameter.
    // Variable names stay the same by overloading on argument label.
    func signUp(user: User, password: String) async throws {
        // Create auth user
        let response = try await supabase.auth.signUp(email: user.email, password: password) // [web:102]
        print(response)

        // Mirror into public.users (id must equal auth user's id)
        let authUserId = response.user.id.uuidString
        let profile = User(
            id: authUserId,
            username: user.username,
            email: user.email,
            created_at: Date().iso8601StringUTC
        )

        // Insert and return inserted row
        let inserted: User = try await supabase
            .from("users")
            .insert(profile)
            .select()
            .single()
            .execute()
            .value                                          // select() to get data back [web:115][web:107]

        self.user = inserted
    }

    func signOut() async throws {
        try await supabase.auth.signOut()                   // ends session [web:99]
        self.user = nil
    }
}
