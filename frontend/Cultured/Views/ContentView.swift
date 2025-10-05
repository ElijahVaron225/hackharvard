import SwiftUI

struct ContentView: View {
    @State private var showCreateView = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                FeedList()
            }
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Feed")
            .safeAreaInset(edge: .bottom) {
                // Bottom section with CTA and tab bar
                VStack(spacing: 0) {
                    // Launch Experience CTA card
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
                    
                    // Bottom tab bar
                    BottomTabBar(
                        onHomeTap: {
                            // Navigate back to root - this will be handled by the NavigationStack
                        },
                        onCreateTap: {
                            showCreateView = true
                        }
                    )
                }
                .background(Color.background)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.background, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showCreateView) {
            CreateView()
        }
    }
}
