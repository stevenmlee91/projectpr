import SwiftUI

// MARK: - Type Scale
//
// 7 semantic roles. Every text element in the app maps to exactly one.
// No raw .font(.system(size:weight:design:)) calls in views — use these.
//
// Rules:
//   metric        → numbers only. Always thin monospaced.
//   displayTitle  → plan names, key headlines. Always light serif.
//   headline      → card titles, workout names. Semibold sans.
//   body          → descriptions, coaching prose. Regular sans.
//   label         → eyebrows, section headers. UPPERCASE, monospaced, kerning 1.5.
//   caption       → dates, metadata, secondary values. Regular sans.
//   metricCaption → unit labels ("/mi", "days", "miles"). Monospaced.

extension Font {
    /// Large numeric metrics: miles, times, race countdowns.
    static func metric(_ size: CGFloat = 38) -> Font {
        .system(size: size, weight: .thin, design: .monospaced)
    }

    /// Plan names and key display headlines with emotional weight.
    static func displayTitle(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .light, design: .serif)
    }

    /// Card section titles, workout type names, primary action labels.
    static func headline(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Workout descriptions, coaching text, all running prose.
    static func appBody(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Eyebrow labels and section headers. Apply .kerning(1.5) and .uppercased().
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    /// Dates, metadata, secondary supporting values.
    static func caption(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Unit labels below/beside metrics: "miles", "days", "/mi", "/km".
    static func metricCaption(_ size: CGFloat = 11) -> Font {
        .system(size: size, design: .monospaced)
    }
}

// MARK: - Spacing Scale

enum Spacing {
    /// 4pt — gap between tightly paired elements (label + value)
    static let xs: CGFloat = 4
    /// 8pt — within-section tight gap
    static let sm: CGFloat = 8
    /// 12pt — standard element gap inside cards
    static let md: CGFloat = 12
    /// 16pt — card internal padding (universal card standard)
    static let lg: CGFloat = 16
    /// 20pt — VStack spacing between card sections
    static let xl: CGFloat = 20
    /// 24pt — between sections within a scroll view
    static let xxl: CGFloat = 24
    /// 32pt — major section separator
    static let section: CGFloat = 32
}

// MARK: - Corner Radius Scale

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 14
    static let xl: CGFloat = 16
}

// MARK: - Label Modifier
//
// Applies the standard eyebrow treatment in one call:
// .font(.label()) + uppercase kerning. Use on all section eyebrows.

struct EyebrowStyle: ViewModifier {
    var size: CGFloat = 10
    func body(content: Content) -> some View {
        content
            .font(.label(size))
            .foregroundColor(.secondary)
            .kerning(1.5)
    }
}

extension View {
    func eyebrow(size: CGFloat = 10) -> some View {
        modifier(EyebrowStyle(size: size))
    }
}
