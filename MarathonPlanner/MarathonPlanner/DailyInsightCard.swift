import SwiftUI

struct DailyInsightCard: View {
    let insight  : DailyInsight
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: insight.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .padding(.top, 1)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = insight.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Colors

    private var iconColor: Color {
        switch insight.category {
        case .raceWeek:    return Color(hex: "FFD60A")
        case .phase:       return Color(hex: "FF9F0A")
        case .missed:      return Color(hex: "FF453A")
        case .upcoming:    return Color(hex: "0A84FF")
        case .progress:    return Color(hex: "30D158")
        case .consistency: return Color(hex: "FF9F0A")
        case .motivation:  return .primary
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.12)
    }
}
