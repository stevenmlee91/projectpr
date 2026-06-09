import Foundation

// MARK: - Strava Configuration
//
// SETUP REQUIRED — before this integration works:
//
//  1. Go to https://www.strava.com/settings/api
//  2. Create an app (or use an existing one)
//  3. Set "Authorization Callback Domain" to: milezero
//  4. Copy your Client ID and Client Secret below
//
// The client secret lives in the app binary. This is the standard
// approach for mobile apps — Strava's own mobile SDK does the same.
// Never commit real credentials to a public repository.

enum StravaConfig {

    // MARK: - Replace these with your Strava developer credentials

    static let clientID     = "225942"      // e.g. "12345"
    static let clientSecret = "3734858ce82057905bdac2310ce7ec64cd5f6185"  // e.g. "abc123..."

    // MARK: - Fixed constants

    /// The URL scheme registered in Info.plist that Strava redirects to.
    /// Host must match the "Authorization Callback Domain" in the Strava
    /// developer portal — set that field to: localhost
    static let redirectURI         = "milezero://localhost/exchange_token"
    static let callbackURLScheme   = "milezero"

    /// Read-only access to activities. No write permissions requested.
    static let scope = "activity:read"

    // MARK: - Derived URLs

    static var authorizeURL: URL {
        var c = URLComponents(string: "https://www.strava.com/oauth/authorize")!
        c.queryItems = [
            URLQueryItem(name: "client_id",       value: clientID),
            URLQueryItem(name: "redirect_uri",    value: redirectURI),
            URLQueryItem(name: "response_type",   value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope",           value: scope),
        ]
        return c.url!
    }

    static let tokenURL      = URL(string: "https://www.strava.com/oauth/token")!
    static let activitiesURL = URL(string: "https://www.strava.com/api/v3/athlete/activities")!
}
