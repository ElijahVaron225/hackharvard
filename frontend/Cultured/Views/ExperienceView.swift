import SwiftUI

struct ExperienceView: View {
    let experience: Experience
    @Environment(\.dismiss) var dismiss
    @State private var isRotationLocked = false
    
    var body: some View {
        ZStack {
            ARViewContainer(
                experience: experience,
                isRotationLocked: $isRotationLocked
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Bottom controls
                HStack(spacing: 20) {
                    // Lock/Unlock button
                    Button(action: {
                        isRotationLocked.toggle()
                    }) {
                        Image(systemName: isRotationLocked ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                    }
                    
                    // Recenter button
                    Button(action: {
                        // Access coordinator through ARViewContainer
                        NotificationCenter.default.post(name: .recenterCamera, object: nil)
                    }) {
                        Image(systemName: "scope")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                    }
                }
                .padding(.bottom, 20)
                
                // Info card
                InfoCard(experience: experience)
            }
        }
        .navigationBarHidden(true)
    }
}

struct InfoCard: View {
    let experience: Experience
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(experience.artifactName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(experience.culture)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(experience.userStory)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.primary)
            }
        }
        .padding(20)
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
        )
        .cornerRadius(24, corners: [.topLeft, .topRight])
    }
}

extension Notification.Name {
    static let recenterCamera = Notification.Name("recenterCamera")
}

#Preview {
    ExperienceView(experience: Experience.testExperience)
}
