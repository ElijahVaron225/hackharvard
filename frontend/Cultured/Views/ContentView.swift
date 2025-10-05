import SwiftUI

struct ContentView: View {
    @State private var showCreateView = false
    @State private var animateGradient = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid glass background with animated gradients
                ZStack {
                    // Base warm cream background
                    Color.background
                        .ignoresSafeArea()
                    
                    // Animated liquid glass effect
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.1),
                            Color.primary.opacity(0.05),
                            Color.primary.opacity(0.08),
                            Color.primary.opacity(0.03)
                        ],
                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                    )
                    .ignoresSafeArea()
                    .animation(
                        Animation.easeInOut(duration: 8)
                            .repeatForever(autoreverses: true),
                        value: animateGradient
                    )
                    
                    // Secondary liquid layer
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.06),
                            Color.clear,
                            Color.primary.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: animateGradient ? .bottomLeading : .topTrailing,
                        endPoint: animateGradient ? .topTrailing : .bottomLeading
                    )
                    .ignoresSafeArea()
                    .animation(
                        Animation.easeInOut(duration: 12)
                            .repeatForever(autoreverses: true),
                        value: animateGradient
                    )
                    
                    // Subtle overlay for depth
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear,
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                
                VStack(spacing: 0) {
                    // Subtle top divider with glass effect
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 0.5)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Subtle divider
                            Rectangle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(height: 0.5)
                            
                            FeedList()
                        }
                    }
                    
                    // Subtle bottom divider
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 0.5)
                    
                    // Transparent footer that blends with liquid glass
                    BottomTabBar(
                        onHomeTap: {
                            // Navigate back to root - this will be handled by the NavigationStack
                        },
                        onCreateTap: {
                            showCreateView = true
                        }
                    )
                    .background(
                        ZStack {
                            // Glassmorphism background for footer
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color.white.opacity(0.1))
                            
                            // Subtle border
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.primary.opacity(0.2), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 1)
                        }
                    )

                    // Modern transparent button with glassmorphism
                    NavigationLink {
                        ExperienceView(experience: .testExperience)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.primary, Color.primary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Launch Experience")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(
                            ZStack {
                                // Glassmorphism background
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.15))
                                
                                // Subtle border
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.primary.opacity(0.3), Color.primary.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                
                                // Inner highlight
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.1), Color.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .shadow(
                            color: Color.primary.opacity(0.2),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 5,
                            x: 0,
                            y: 2
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .buttonStyle(.plain)
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
