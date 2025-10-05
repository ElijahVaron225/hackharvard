import SwiftUI

// MARK: - Reusable App Background Modifier
struct AppBackgroundModifier: ViewModifier {
    let backgroundColor: Color
    let accentColor: Color
    @State private var animateGradient = false
    
    func body(content: Content) -> some View {
        ZStack {
            // App background that fills behind status bar/Dynamic Island
            backgroundColor
                .ignoresSafeArea(.all)
            
            // Subtle animated accent
            LinearGradient(
                colors: [
                    accentColor.opacity(0.03),
                    Color.clear,
                    accentColor.opacity(0.02)
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
            
            content
        }
        .onAppear {
            animateGradient = true
        }
    }
}

// MARK: - View Extension
extension View {
    func appBackground(backgroundColor: Color = .background, accentColor: Color = .primary) -> some View {
        modifier(AppBackgroundModifier(backgroundColor: backgroundColor, accentColor: accentColor))
    }
}

struct ContentView: View {
    @State private var showCreateView = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    FeedList()
                }
                .scrollContentBackground(.hidden) // Hide default ScrollView background
                
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
        }
        .appBackground() // Apply reusable background modifier
        .toolbarBackground(.visible, for: .navigationBar) // Match navigation bar to background
        .toolbarBackground(Color.background, for: .navigationBar) // Set navigation bar color
        .fullScreenCover(isPresented: $showCreateView) {
            CreateView()
        }
    }
}
