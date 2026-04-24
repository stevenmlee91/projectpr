import SwiftUI

struct PlanView: View {
    let weeks: [TrainingWeek]
    let settings: UserSettings
    
    var body: some View {
        NavigationView {
            List(weeks) { week in
                NavigationLink(destination: WeekDetailView(week: week, settings: settings)) {
                    WeekRow(week: week)
                }
            }
            .navigationTitle("Training Plan")
        }
    }
}

// One row in the plan list showing a week summary
struct WeekRow: View {
    let week: TrainingWeek
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(week.label)
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "%.1f mi", week.totalMiles))
                    .foregroundColor(.secondary)
            }
            
            // Mini day strip
            HStack(spacing: 4) {
                ForEach(week.days) { day in
                    DayDot(workoutType: day.workoutType, miles: day.miles)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// A tiny colored dot showing what type of day it is
struct DayDot: View {
    let workoutType: WorkoutType
    let miles: Double
    
    var dotColor: Color {
        switch workoutType {
        case .rest:
            return .gray.opacity(0.3)
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
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
        }
    }
}
