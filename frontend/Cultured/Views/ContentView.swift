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
                // Bottom tab bar only
                BottomTabBar(
                    onHomeTap: {
                        // Navigate back to root - this will be handled by the NavigationStack
                    },
                    onCreateTap: {
                        showCreateView = true
                    }
                )
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
