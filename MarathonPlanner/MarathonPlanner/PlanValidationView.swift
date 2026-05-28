import SwiftUI

// MARK: - Plan Validation View

struct PlanValidationView: View {
    let plan   : SavedPlan
    @Environment(\.dismiss) private var dismiss

    private var report: ValidationReport {
        PlanValidator.validate(plan)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        scoreHeader
                        if report.isClean {
                            cleanBadge
                        } else {
                            issuesList
                        }
                        checksFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Plan Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 20) {
            HStack(spacing: 24) {
                scoreRing
                VStack(alignment: .leading, spacing: 6) {
                    Text(report.scoreLabel.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(scoreColor)
                        .kerning(1.5)
                    Text(headerMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        if !report.errors.isEmpty {
                            issueCountChip(
                                count: report.errors.count,
                                label: report.errors.count == 1 ? "error" : "errors",
                                color: Color(hex: "FF453A")
                            )
                        }
                        if !report.warnings.isEmpty {
                            issueCountChip(
                                count: report.warnings.count,
                                label: report.warnings.count == 1 ? "warning" : "warnings",
                                color: Color(hex: "FF9F0A")
                            )
                        }
                        if !report.infos.isEmpty {
                            issueCountChip(
                                count: report.infos.count,
                                label: report.infos.count == 1 ? "note" : "notes",
                                color: .secondary
                            )
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 6)
                .frame(width: 72, height: 72)
            Circle()
                .trim(from: 0, to: CGFloat(report.score) / 100.0)
                .stroke(scoreColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(report.score)")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                Text("/ 100")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func issueCountChip(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private var scoreColor: Color {
        switch report.score {
        case 90...100: return Color(hex: "30D158")
        case 75..<90:  return Color(hex: "0A84FF")
        case 55..<75:  return Color(hex: "FF9F0A")
        default:       return Color(hex: "FF453A")
        }
    }

    private var headerMessage: String {
        if report.isClean { return "No issues found." }
        let eCount = report.errors.count
        let wCount = report.warnings.count
        if eCount > 0 && wCount > 0 {
            return "\(eCount) error\(eCount == 1 ? "" : "s") and \(wCount) warning\(wCount == 1 ? "" : "s") detected."
        } else if eCount > 0 {
            return "\(eCount) error\(eCount == 1 ? "" : "s") detected."
        } else {
            return "\(wCount) warning\(wCount == 1 ? "" : "s") to review."
        }
    }

    // MARK: - Clean Badge

    private var cleanBadge: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Color(hex: "30D158"))
            Text("Plan looks solid.")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
            Text("All \(report.checksRun) checks passed. Your plan follows sound training principles.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Issues List

    private var issuesList: some View {
        VStack(spacing: 12) {
            if !report.errors.isEmpty {
                issueSection(
                    title:  "Errors",
                    issues: report.errors,
                    color:  Color(hex: "FF453A")
                )
            }
            if !report.warnings.isEmpty {
                issueSection(
                    title:  "Warnings",
                    issues: report.warnings,
                    color:  Color(hex: "FF9F0A")
                )
            }
            if !report.infos.isEmpty {
                issueSection(
                    title:  "Notes",
                    issues: report.infos,
                    color:  .secondary
                )
            }
        }
    }

    private func issueSection(
        title  : String,
        issues : [ValidationIssue],
        color  : Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .kerning(1.5)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                ForEach(issues) { issue in
                    issueRow(issue: issue, color: color)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func issueRow(issue: ValidationIssue, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.severity.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(issue.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let week = issue.weekNumber {
                        Text("WK \(week)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(color.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.12))
                            .cornerRadius(4)
                    }
                }
                Text(issue.detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Footer

    private var checksFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(report.checksRun) checks run · \(report.checksRun - report.issues.count) passed")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
}
