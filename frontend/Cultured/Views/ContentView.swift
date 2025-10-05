import SwiftUI

struct ContentView: View {
    @State private var showCreateView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern gradient background using global colors
                LinearGradient(
                    colors: [Color.background, Color.background.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
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
                    
                    BottomTabBar(
                        onHomeTap: {
                            // Navigate back to root - this will be handled by the NavigationStack
                        },
                        onCreateTap: {
                            showCreateView = true
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
        .fullScreenCover(isPresented: $showCreateView) {
            CreateView()
        }
    }
}
