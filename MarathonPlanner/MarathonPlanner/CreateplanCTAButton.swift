import SwiftUI

// MARK: - Create Plan CTA Button

struct CreatePlanCTAButton: View {
    @Binding var showCreatePlan: Bool

    var body: some View {
        VStack(spacing: 12) {
            Button {
                showCreatePlan = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 15, weight: .medium))
                    Text("Create New Plan")
                        .font(.system(size: 15, weight: .semibold,
                                      design: .monospaced))
                        .kerning(0.5)
                }
                .foregroundColor(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.label))
                        .shadow(color: Color(.label).opacity(0.18),
                                radius: 12, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)

            Text("Build your next race plan in under a minute.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}
