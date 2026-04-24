import SwiftUI

struct WeekDetailView: View {
    let week: TrainingWeek
    let settings: UserSettings
    
    var paces: TrainingPaces {
        TrainingPaces.calculate(goalMinutes: settings.goalTimeMinutes)
    }
    
    var body: some View {
        List(week.days) { day in
            DayRow(day: day, paces: paces)
        }
        .navigationTitle(week.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DayRow: View {
    let day: TrainingDay
    let paces: TrainingPaces
    
    var dotColor: Color {
        switch day.workoutType {
        case .rest:
            return .gray
        case .easy, .recovery, .strides, .generalAerobic:
            return .green
        case .longRun, .longRunWithMP, .mediumLong:
            return .blue
        case .tempoRun, .marathonPace, .strengthMP:
            return .orange
        case .lactateThreshold, .cruiseIntervals, .intervalWork, .speedWork:
            return .red
        case .repetitionWork:
            return .purple
        default:
            return .gray
        }
    }
    
    var paceString: String? {
        switch day.workoutType {
        case .easy:      return "\(TrainingPaces.format(paces.easy.min))–\(TrainingPaces.format(paces.easy.max))/mi"
        case .longRun:   return "\(TrainingPaces.format(paces.longRun.min))–\(TrainingPaces.format(paces.longRun.max))/mi"
        case .tempoRun:     return "\(TrainingPaces.format(paces.tempo))/mi"
        case .intervalWork: return "\(TrainingPaces.format(paces.interval))/mi"
        case .marathonPace:  return "\(TrainingPaces.format(paces.marathon))/mi"
        case .recovery:  return "\(TrainingPaces.format(paces.recovery))/mi"
        default:         return nil
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Day name + color indicator
            VStack {
                Circle().fill(dotColor).frame(width: 12, height: 12)
                    .padding(.top, 3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(day.weekday.fullName).fontWeight(.semibold)
                    Spacer()
                    if day.miles > 0 {
                        Text(String(format: "%.1f mi", day.miles))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(day.workoutType.rawValue)
                    .font(.subheadline)
                    .foregroundColor(dotColor)
                
                Text(day.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let pace = paceString {
                    Text("Target: \(pace)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
