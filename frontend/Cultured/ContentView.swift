import SwiftUI
struct ContentView: View {
    var body: some View {
        ZStack{
            Color(.systemBackground)
                .ignoresSafeArea(.all)
            VStack(spacing: 0){
                Divider()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0){
                        Divider()
                        FeedList()

                    }
                }
                Divider()
                BottomTabBar()
                
            }
            
        }
        .background(Color.black)
        .ignoresSafeArea(.container, edges: .top)
        
    }
}



#Preview {
    ContentView()
}
