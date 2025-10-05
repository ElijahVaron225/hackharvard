import SwiftUI

struct ContentView: View {
    @State private var showCreateView = false
    @State private var animateGradient = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Clean iOS 16+ style background
                Color.background
                    .ignoresSafeArea(.all)
                
                // Subtle animated accent
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.03),
                        Color.clear,
                        Color.primary.opacity(0.02)
                    ],
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .ignoresSafeArea(.all)
                .animation(
                    Animation.easeInOut(duration: 15)
                        .repeatForever(autoreverses: true),
                    value: animateGradient
                )
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        FeedList()
                    }
                    
                    // iOS 16+ style translucent tab bar
                    BottomTabBar(
                        onHomeTap: {
                            // Navigate back to root - this will be handled by the NavigationStack
                        },
                        onCreateTap: {
                            showCreateView = true
                        }
                    )

                    // iOS 16+ style button
                    NavigationLink {
                        ExperienceView(experience: .testExperience)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                            Text("Launch Experience")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .buttonStyle(.plain)
                }
                .safeAreaInset(edge: .top) {
                    // Ensure proper top safe area handling
                    Color.clear.frame(height: 0)
                }
            }
        }
        .onAppear {
            animateGradient = true
        }
        .fullScreenCover(isPresented: $showCreateView) {
            CreateView()
        }
    }
}
