import SwiftUI

struct LandingPageView: View {
    @State private var showLogin = false
    @State private var showSignUp = false
    
    var body: some View {
        VStack {
            Button("Login") {
                showLogin = true
            }
            
            Button("Sign Up") {
                showSignUp = true
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }
}
