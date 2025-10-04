import SwiftUI

struct TestView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("3D Experience Test")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Hardcoded Asset URLs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        URLDisplayRow(
                            title: "Skybox Image",
                            url: Experience.testExperience.skyboxURL,
                            icon: "photo"
                        )
                        
                        URLDisplayRow(
                            title: "3D Model",
                            url: Experience.testExperience.modelURL,
                            icon: "cube"
                        )
                    }
                    .padding(.horizontal)
                    
                    NavigationLink(destination: ExperienceView(experience: Experience.testExperience)) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                            Text("Launch Experience")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct URLDisplayRow: View {
    let title: String
    let url: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            Text(url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

#Preview {
    TestView()
}
