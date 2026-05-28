import SwiftUI

struct DailyInsightCard: View {
    let insight  : DailyInsight
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 16, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = insight.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(iconColor.opacity(0.08))
        .cornerRadius(10)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 4)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                appeared = true
            }
        }
    }

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
}
