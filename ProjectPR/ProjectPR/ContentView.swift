import SwiftUI

enum Weekday: String, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    
    var id: String { self.rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
}
    
enum PlanType: String, CaseIterable, Identifiable {
    case higdon = "Higdon"
    case pfitz = "Pfitz"
    case hansons = "Hansons"
    case daniels = "Daniels"

    var id: String { self.rawValue }
}


struct ContentView: View {
    
    @State private var longRunDay: Weekday = .saturday
    @State private var workoutDays: Set<Weekday> = [.tuesday]
    @State private var restDays: Set<Weekday> = [.friday]
    @State private var goalTime = ""
    @State private var selectedWeeks = 12
    @State private var selectedPlan: PlanType = .higdon
    @State private var baseMileage = ""
    let weekOptions = [12, 16, 18]
    
    var body: some View {
        ZStack {
            
            Color.black
                .ignoresSafeArea()

            ScrollView {

                VStack(spacing: 18) {

                    // HEADER
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Marathon Planner")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Build your personalized training plan")
                            .font(.subheadline)
                            .foregroundColor(.green.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // CARD WRAPPER
                    VStack(spacing: 18) {

                        // GOAL TIME
                        inputCard(title: "Goal Marathon Time (hh:mm)") {
                            TextField("3:45", text: $goalTime)
                                .keyboardType(.numbersAndPunctuation)
                                .foregroundColor(.white)
                        }

                        // PLAN LENGTH
                        inputCard(title: "Plan Length") {
                            Picker("", selection: $selectedWeeks) {
                                ForEach(weekOptions, id: \.self) { week in
                                    Text("\(week) weeks").tag(week)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        // PLAN TYPE
                        inputCard(title: "Training Plan") {
                            Picker("", selection: $selectedPlan) {
                                ForEach(PlanType.allCases) { plan in
                                    Text(plan.rawValue).tag(plan)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        // LONG RUN DAY
                        inputCard(title: "Long Run Day") {
                            Picker("", selection: $longRunDay) {
                                ForEach(Weekday.allCases) { day in
                                    Text(day.displayName).tag(day)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }

                        // WORKOUT DAYS
                        inputCard(title: "Workout Days") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Weekday.allCases) { day in
                                    Toggle(day.displayName, isOn: Binding(
                                        get: { workoutDays.contains(day) },
                                        set: { isOn in
                                            if isOn {
                                                workoutDays.insert(day)
                                            } else {
                                                workoutDays.remove(day)
                                            }
                                        }
                                    ))
                                    .tint(.green)
                                }
                            }
                        }

                        // REST DAYS
                        inputCard(title: "Rest Days") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Weekday.allCases) { day in
                                    Toggle(day.displayName, isOn: Binding(
                                        get: { restDays.contains(day) },
                                        set: { isOn in
                                            if isOn {
                                                restDays.insert(day)
                                            } else {
                                                restDays.remove(day)
                                            }
                                        }
                                    ))
                                    .tint(.green)
                                }
                            }
                        }

                        // GENERATE BUTTON
                        NavigationLink(destination: PlanView(
                            goalTime: goalTime,
                            weeks: selectedWeeks,
                            longRunDay: longRunDay,
                            workoutDays: workoutDays,
                            restDays: restDays,
                            planType: selectedPlan,
                            baseMileage: Double(baseMileage) ?? 25.0
                        )) {
                            Text("Generate Training Plan")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(.black)
                                .cornerRadius(12)
                                .shadow(color: .green.opacity(0.3), radius: 8)
                        }
                        .padding(.top, 10)

                    }
                    .padding()
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }
    func inputCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            Text(title)
                .font(.caption)
                .foregroundColor(.green.opacity(0.8))

            content()
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        }
    }
}
