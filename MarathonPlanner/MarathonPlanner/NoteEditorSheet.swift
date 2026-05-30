import SwiftUI

struct NoteEditorSheet: View {
    let day    : SavedDay
    let planID : UUID
    let weekID : UUID
    @EnvironmentObject var store: PlanStore
    @Environment(\.dismiss) var dismiss

    @State private var noteInput = ""
    @FocusState private var focused: Bool

    private let limit = 250

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("HOW DID IT FEEL?")
                        .font(.system(size: 11, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(2)
                    Text(day.workoutType)
                        .font(.system(size: 18, weight: .light,
                                      design: .serif))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 24)

                ZStack(alignment: .topLeading) {
                    if noteInput.isEmpty {
                        Text("Legs felt strong, negative split, shin a bit tight...")
                            .font(.system(size: 14))
                            .foregroundColor(Color(.tertiaryLabel))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $noteInput)
                        .focused($focused)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .onChange(of: noteInput) { val in
                            if val.count > limit {
                                noteInput = String(val.prefix(limit))
                            }
                        }
                }
                .frame(minHeight: 140)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)

                HStack {
                    Text("\(noteInput.count)/\(limit)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(noteInput.count > limit - 20
                                         ? Color(hex: "FF453A")
                                         : .secondary)
                    Spacer()
                }
                .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    Button("Skip") {
                        dismiss()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .buttonStyle(.plain)

                    Button {
                        store.saveNote(planID: planID, weekID: weekID,
                                       dayID: day.id, note: noteInput)
                        dismiss()
                    } label: {
                        Text("Save Note")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "30D158"))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .onAppear {
            noteInput = day.completionNote ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focused = true
            }
        }
    }
}
