import SwiftUI

struct MainTabView: View {
    @State private var settings = UserSettings()
    @State private var generatedWeeks: [TrainingWeek] = []
    @State private var hasGenerated = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            // Tab 1: Setup
            SetupView(settings: $settings) {
                // Called when Generate is tapped
                generatedWeeks = PlanGenerator.generate(settings: settings)
                hasGenerated = true
                selectedTab = 1   // jump to Plan tab
            }
            .tabItem { Label("Setup", systemImage: "slider.horizontal.3") }
            .tag(0)

            // Tab 2: Plan
            Group {
                if hasGenerated {
                    PlanView(weeks: generatedWeeks, settings: settings)
                } else {
                    ZStack {
                        Color(hex: "0F0F0F").ignoresSafeArea()
                        VStack(spacing: 12) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 44, weight: .ultraLight))
                                .foregroundColor(Color(hex: "3A3A3A"))
                            Text("No plan yet")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(Color(hex: "5E5E5E"))
                            Text("Go to Setup and tap Generate Plan")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(hex: "3A3A3A"))
                        }
                    }
                }
            }
            .tabItem { Label("Plan", systemImage: "calendar") }
            .tag(1)

            // Tab 3: Paces
            PacesView(settings: settings)
                .tabItem { Label("Paces", systemImage: "speedometer") }
                .tag(2)
        }
        .accentColor(.white)
    }
}
