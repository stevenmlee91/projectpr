import Foundation

// MARK: - Strava API Models

// MARK: Token response (OAuth exchange + refresh)

struct StravaTokenResponse: Decodable {
    let accessToken  : String
    let refreshToken : String
    let expiresAt    : Int          // Unix timestamp when access token expires
    let athlete      : StravaAthlete

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt    = "expires_at"
        case athlete
    }
}

// MARK: Athlete

struct StravaAthlete: Decodable {
    let id        : Int
    let firstname : String
    let lastname  : String

    var displayName: String { "\(firstname) \(lastname)" }
}

// MARK: Activity

struct StravaActivity: Decodable, Identifiable {
    let id               : Int
    let name             : String
    let distance         : Double   // meters
    let movingTime       : Int      // seconds
    let startDate        : Date     // UTC — used for calendar-day matching
    let type             : String   // "Run", "VirtualRun", "TrailRun", etc.
    let averageSpeed     : Double?  // m/s
    let totalElevationGain: Double? // meters

    enum CodingKeys: String, CodingKey {
        case id, name, distance, type
        case movingTime         = "moving_time"
        case startDate          = "start_date"
        case averageSpeed       = "average_speed"
        case totalElevationGain = "total_elevation_gain"
    }

    // MARK: - Computed helpers

    /// Distance in miles (rounded to 2 decimal places).
    var distanceMiles: Double {
        (distance / 1609.344 * 100).rounded() / 100
    }

    /// True for any running activity type Strava produces.
    var isRun: Bool {
        ["Run", "VirtualRun", "TrailRun"].contains(type)
    }

    /// Average pace as "m:ss/mi" string, or nil if speed is unavailable.
    var pacePerMile: String? {
        guard let speed = averageSpeed, speed > 0 else { return nil }
        let secsPerMile = 1609.344 / speed
        let mins = Int(secsPerMile) / 60
        let secs = Int(secsPerMile) % 60
        return String(format: "%d:%02d/mi", mins, secs)
    }

    /// Moving time formatted as "h:mm:ss" or "mm:ss".
    var formattedDuration: String {
        let h = movingTime / 3600
        let m = (movingTime % 3600) / 60
        let s = movingTime % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Match confidence

/// How closely a Strava activity matches a planned SavedDay workout.
enum StravaMatchConfidence {
    /// Within 10% of planned distance — treat as completed.
    case strong
    /// Within 25% of planned distance — treat as modified.
    case partial
    /// Same day, is a run, but distance diverges more than 25%.
    case dayOnly
}

/// A resolved match between a Strava activity and a planned workout day.
struct StravaMatch {
    let activity   : StravaActivity
    let dayID      : UUID
    let weekID     : UUID
    let planID     : UUID
    let confidence : StravaMatchConfidence
}
