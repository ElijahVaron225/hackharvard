import SwiftUI

struct ContentView: View {
    @State private var showCreateView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    Divider()
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Divider()
                            FeedList()
                        }
                    }
                    Divider()
                    BottomTabBar(
                        onHomeTap: {
                            // Navigate back to root - this will be handled by the NavigationStack
                        },
                        onCreateTap: {
                            showCreateView = true
                        }
                    )

                    // Put the link inside the NavigationStack
                    NavigationLink {
                        ExperienceView(experience: .testExperience)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill").font(.title2)
                            Text("Launch Experience").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .blue.opacity(0.8)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .buttonStyle(.plain)
                }
            }
            .background(Color.black)
            .ignoresSafeArea(.container, edges: .top)
        }
        .fullScreenCover(isPresented: $showCreateView) {
            CreateView()
        }
    }
}
