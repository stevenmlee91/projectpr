import SwiftUI

struct PacesView: View {
    let settings: UserSettings
    
    var paces: TrainingPaces {
        TrainingPaces.calculate(goalMinutes: settings.goalTimeMinutes)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Goal: \(settings.goalTimeFormatted)")) {
                    PaceRow(label: "Marathon Pace",    pace: TrainingPaces.format(paces.marathon),  detail: "Race day goal pace",                  color: .orange)
                    PaceRow(label: "Tempo Pace",       pace: TrainingPaces.format(paces.tempo),     detail: "Comfortably hard — 4–8 mile effort",  color: .red)
                    PaceRow(label: "Long Run Pace",    pace: "\(TrainingPaces.format(paces.longRun.min))–\(TrainingPaces.format(paces.longRun.max))",
                                                                                                    detail: "60–90 sec/mi slower than MP",         color: .blue)
                    PaceRow(label: "Easy Pace",        pace: "\(TrainingPaces.format(paces.easy.min))–\(TrainingPaces.format(paces.easy.max))",
                                                                                                    detail: "Conversational. Most of your miles.",  color: .green)
                    PaceRow(label: "Interval Pace",    pace: TrainingPaces.format(paces.interval),  detail: "~5K effort — short repeats",          color: .purple)
                    PaceRow(label: "Recovery Pace",    pace: TrainingPaces.format(paces.recovery),  detail: "Very easy. After hard workouts.",      color: .gray)
                }
                
                Section(header: Text("How to use these paces")) {
                    Text("All paces are per mile. Run by feel — if a pace feels too hard, slow down. These are targets, not rules.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Your Paces")
        }
    }
}

// A reusable row for showing one pace
struct PaceRow: View {
    let label: String
    let pace: String
    let detail: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label).fontWeight(.medium)
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(pace)/mi")
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}
