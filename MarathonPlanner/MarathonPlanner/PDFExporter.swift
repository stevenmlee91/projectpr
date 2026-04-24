import UIKit
import PDFKit

// MARK: - PDF Exporter

struct PDFExporter {

    static func exportPlan(_ plan: SavedPlan) -> URL {
        let pageWidth  : CGFloat = 612   // US Letter
        let pageHeight : CGFloat = 792
        let margin     : CGFloat = 48

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let dateFormatter        = DateFormatter()
        dateFormatter.dateStyle  = .medium
        let shortDateFormatter   = DateFormatter()
        shortDateFormatter.dateFormat = "EEE, MMM d"

        let data = renderer.pdfData { ctx in
            var yPos: CGFloat = 0

            func newPage() {
                ctx.beginPage()
                yPos = margin
            }

            func checkPageBreak(neededHeight: CGFloat) {
                if yPos + neededHeight > pageHeight - margin {
                    newPage()
                }
            }

            // MARK: Draw Title Page
            newPage()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .light),
                .foregroundColor: UIColor.black
            ]
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            // Title
            let titleStr = NSAttributedString(string: plan.name, attributes: titleAttrs)
            titleStr.draw(at: CGPoint(x: margin, y: yPos))
            yPos += 40

            // Method + dates
            let meta = "\(plan.planType.uppercased())  •  \(dateFormatter.string(from: plan.startDate)) – \(dateFormatter.string(from: plan.raceDate))"
            NSAttributedString(string: meta, attributes: subtitleAttrs)
                .draw(at: CGPoint(x: margin, y: yPos))
            yPos += 24

            // Divider
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: margin, y: yPos))
            dividerPath.addLine(to: CGPoint(x: pageWidth - margin, y: yPos))
            UIColor.lightGray.setStroke()
            dividerPath.lineWidth = 0.5
            dividerPath.stroke()
            yPos += 20

            // MARK: Draw Each Week
            for week in plan.weeks {
                checkPageBreak(neededHeight: 120)

                // Week header
                let weekHeaderAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.black
                ]
                let weekLabel = "Week \(week.weekNumber)  —  \(week.phase)"
                NSAttributedString(string: weekLabel, attributes: weekHeaderAttrs)
                    .draw(at: CGPoint(x: margin, y: yPos))

                let mileStr = String(format: "%.0f mi", week.totalMiles)
                let mileAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.gray
                ]
                let mileWidth = (mileStr as NSString).size(withAttributes: mileAttrs).width
                NSAttributedString(string: mileStr, attributes: mileAttrs)
                    .draw(at: CGPoint(x: pageWidth - margin - mileWidth, y: yPos))
                yPos += 22

                // Days
                for day in week.days {
                    checkPageBreak(neededHeight: 40)

                    let isRest = day.workoutType == "Rest"

                    // Day date
                    let dateStr = shortDateFormatter.string(from: day.date)
                    NSAttributedString(string: dateStr, attributes: subtitleAttrs)
                        .draw(at: CGPoint(x: margin + 8, y: yPos))

                    // Workout type
                    let typeAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: isRest ? .light : .medium),
                        .foregroundColor: isRest ? UIColor.lightGray : UIColor.black
                    ]
                    NSAttributedString(string: day.workoutType, attributes: typeAttrs)
                        .draw(at: CGPoint(x: margin + 100, y: yPos))

                    // Miles
                    if day.miles > 0 {
                        let mi = String(format: "%.1f mi", day.miles)
                        NSAttributedString(string: mi, attributes: bodyAttrs)
                            .draw(at: CGPoint(x: margin + 260, y: yPos))
                    }

                    // Pace note
                    if day.paceNote != "—" && !day.paceNote.isEmpty {
                        NSAttributedString(string: day.paceNote, attributes: subtitleAttrs)
                            .draw(at: CGPoint(x: margin + 320, y: yPos))
                    }

                    yPos += 18

                    // Description (skip for rest)
                    if !isRest {
                        let descAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 9, weight: .light),
                            .foregroundColor: UIColor.gray
                        ]
                        let maxWidth = pageWidth - margin * 2 - 8
                        let descStr  = NSAttributedString(string: day.description, attributes: descAttrs)
                        let descRect = CGRect(x: margin + 8, y: yPos, width: maxWidth, height: 200)
                        let drawn    = descStr.boundingRect(with: descRect.size, options: .usesLineFragmentOrigin, context: nil)
                        descStr.draw(with: descRect, options: .usesLineFragmentOrigin, context: nil)
                        yPos += drawn.height + 4
                    }

                    yPos += 4
                }

                // Week separator
                let sep = UIBezierPath()
                sep.move(to: CGPoint(x: margin, y: yPos + 6))
                sep.addLine(to: CGPoint(x: pageWidth - margin, y: yPos + 6))
                UIColor(white: 0.9, alpha: 1).setStroke()
                sep.lineWidth = 0.5
                sep.stroke()
                yPos += 20
            }
        }

        // Write to temp file
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(plan.name.replacingOccurrences(of: " ", with: "_"))_TrainingPlan.pdf")
        try? data.write(to: url)
        return url
    }
}
