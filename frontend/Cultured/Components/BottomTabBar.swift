//
    // Project: InstagramRecreation2
    //  File: BottomTabBar.swift
    //  Created by Noah Carpenter
    //  🐱 Follow me on YouTube! 🎥
    //  https://www.youtube.com/@NoahDoesCoding97
    //  Like and Subscribe for coding tutorials and fun! 💻✨
    //  Fun Fact: Cats have five toes on their front paws, but only four on their back paws! 🐾
    //  Dream Big, Code Bigger
    

import SwiftUI

struct BottomTabBar: View {
    @State private var selected = 0

    var body: some View {
        HStack {
            Spacer()
            TabItem(icon: "house.fill", index: 0, selected: $selected)
            Spacer()
            TabItem(icon: "plus.app.fill", index: 2, selected: $selected)
            Spacer()
            TabItem(icon: "person.circle", index: 4, selected: $selected)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 14)                 // room above home indicator
        .background(.ultraThinMaterial)       // <-- blur instead of Color(...)
        .overlay(Divider(), alignment: .top)  // subtle top hairline
        // (optional) floating rounded look:
        // .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // .shadow(radius: 8, y: 2)
    }
}
struct TabItem: View{
    let icon: String
    let index: Int
    @Binding var selected: Int
    
    var body: some View{
        
        VStack{
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(selected == index ? .primary : .secondary)
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            selected = index
        }
        .toolbarBackground(.visible, for: .tabBar)
        .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.7)            // <-- make it “more see-through”
                }
        // Let content be visible behind the bar if you want that effect
        .ignoresSafeArea(.container, edges: .bottom)
    }
}


#Preview {
    BottomTabBar()
}
