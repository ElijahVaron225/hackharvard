import SwiftUI

struct ProfileView: View {
    @State private var userExperiences: [Experience] = [
        Experience.testExperience,
        Experience.testExperience,
        Experience.testExperience
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Profile Header
                    ProfileHeaderView()
                    
                    Divider()
                    
                    // Stats Section
                    ProfileStatsView()
                    
                    Divider()
                    
                    // Experiences Grid
                    ProfileExperiencesView(experiences: userExperiences)
                    
                    Divider()
                    
                    // Settings Section
                    ProfileSettingsView()
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
}

struct ProfileHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Profile Picture and Name
            VStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                
                VStack(spacing: 4) {
                    Text("Cultural Explorer")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("@cultural_explorer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Bio
            Text("Discovering cultural heritage through immersive 3D experiences. Sharing stories that connect us across time and space.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
    }
}

struct ProfileStatsView: View {
    var body: some View {
        HStack(spacing: 0) {
            StatItemView(number: "12", label: "Experiences")
            Divider()
                .frame(height: 40)
            StatItemView(number: "8", label: "Cultures")
            Divider()
                .frame(height: 40)
            StatItemView(number: "24", label: "Stories")
        }
        .padding(.vertical, 20)
    }
}

struct StatItemView: View {
    let number: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProfileExperiencesView: View {
    let experiences: [Experience]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Experiences")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("See All") {
                    // Navigate to full experiences list
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(experiences.prefix(4)) { experience in
                    ExperienceCardView(experience: experience)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct ExperienceCardView: View {
    let experience: Experience
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .overlay(
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(experience.artifactName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(experience.culture)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct ProfileSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            SettingsRowView(
                icon: "gear",
                title: "Settings",
                action: {}
            )
            
            Divider()
                .padding(.leading, 50)
            
            SettingsRowView(
                icon: "bell",
                title: "Notifications",
                action: {}
            )
            
            Divider()
                .padding(.leading, 50)
            
            SettingsRowView(
                icon: "questionmark.circle",
                title: "Help & Support",
                action: {}
            )
            
            Divider()
                .padding(.leading, 50)
            
            SettingsRowView(
                icon: "info.circle",
                title: "About",
                action: {}
            )
        }
        .padding(.vertical, 8)
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView()
}