import Foundation
import AuthenticationServices
import UIKit

// MARK: - Strava Service
//
// Handles OAuth2 authentication, token lifecycle, activity fetching,
// and matching Strava activities to planned SavedDay workouts.
//
// Inject as @EnvironmentObject. Syncs on app foreground — no background
// tasks required since we only need the last 14 days of activity data.

@MainActor
final class StravaService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var isConnected      : Bool          = false
    @Published var athleteName      : String        = ""
    @Published var isSyncing        : Bool          = false
    @Published var syncError        : String?       = nil

    /// All running activities fetched in the last sync (last 14 days).
    @Published var recentActivities : [StravaActivity] = []

    /// Matched Strava activities keyed by SavedDay.id.
    /// Only contains days that are not yet completed.
    @Published var matches          : [UUID: StravaActivity] = [:]

    // MARK: - Persisted state (non-sensitive)

    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "strava_last_sync") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "strava_last_sync") }
    }

    private enum UDKeys {
        static let athleteName = "strava_athlete_name"
        static let athleteID   = "strava_athlete_id"
    }

    // MARK: - Private

    /// Retained so ASWebAuthenticationSession is not deallocated during auth.
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Init

    override init() {
        super.init()
        restoreState()
    }

    private func restoreState() {
        isConnected = KeychainHelper.load(for: StravaKeys.accessToken) != nil
        athleteName = UserDefaults.standard.string(forKey: UDKeys.athleteName) ?? ""
    }

    // MARK: - Connect (OAuth2)

    func connect() async {
        syncError = nil
        do {
            let code = try await withCheckedThrowingContinuation {
                (cont: CheckedContinuation<String, Error>) in

                let session = ASWebAuthenticationSession(
                    url:               StravaConfig.authorizeURL,
                    callbackURLScheme: StravaConfig.callbackURLScheme
                ) { callbackURL, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    guard
                        let url = callbackURL,
                        let code = URLComponents(
                            url: url,
                            resolvingAgainstBaseURL: false
                        )?.queryItems?.first(where: { $0.name == "code" })?.value
                    else {
                        cont.resume(throwing: StravaError.invalidCallback)
                        return
                    }
                    cont.resume(returning: code)
                }

                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.authSession = session

                guard session.start() else {
                    cont.resume(throwing: StravaError.sessionFailed)
                    return
                }
            }

            try await exchangeCode(code)

        } catch ASWebAuthenticationSessionError.canceledLogin {
            // User tapped Cancel — not an error worth surfacing
        } catch StravaError.apiMessage(let msg) {
            syncError = msg
        } catch {
            syncError = "Could not connect to Strava. Please try again."
        }

        authSession = nil
    }

    // MARK: - Disconnect

    func disconnect() {
        KeychainHelper.clearStrava()
        UserDefaults.standard.removeObject(forKey: UDKeys.athleteName)
        UserDefaults.standard.removeObject(forKey: UDKeys.athleteID)
        UserDefaults.standard.removeObject(forKey: "strava_last_sync")
        isConnected      = false
        athleteName      = ""
        recentActivities = []
        matches          = [:]
        syncError        = nil
    }

    // MARK: - Sync

    /// Fetches the last 14 days of Strava activities and matches them to
    /// unlogged plan days. Safe to call on every foreground transition.
    func sync(plans: [SavedPlan]) async {
        guard isConnected, !isSyncing else { return }
        isSyncing = true
        syncError = nil

        do {
            let token      = try await validAccessToken()
            let after      = Date().addingTimeInterval(-14 * 86_400)
            let activities = try await fetchActivities(after: after, token: token)

            recentActivities = activities
            lastSyncDate     = Date()
            computeMatches(activities: activities, plans: plans)

        } catch StravaError.notAuthenticated {
            disconnect()
        } catch StravaError.apiMessage(let msg) {
            syncError = msg
        } catch {
            syncError = "Sync failed. Check your connection and try again."
        }

        isSyncing = false
    }

    // MARK: - Remove a match after the runner logs it

    func clearMatch(for dayID: UUID) {
        matches.removeValue(forKey: dayID)
    }

    // MARK: - Token management

    private func validAccessToken() async throws -> String {
        guard
            let access  = KeychainHelper.load(for: StravaKeys.accessToken),
            let refresh = KeychainHelper.load(for: StravaKeys.refreshToken),
            let expStr  = KeychainHelper.load(for: StravaKeys.expiresAt),
            let expInt  = Int(expStr)
        else { throw StravaError.notAuthenticated }

        // If the token expires more than 5 minutes from now, use it directly
        if Date().timeIntervalSince1970 < Double(expInt) - 300 {
            return access
        }

        // Refresh
        return try await refreshToken(refreshToken: refresh)
    }

    private func exchangeCode(_ code: String) async throws {
        let body: [String: String] = [
            "client_id":     StravaConfig.clientID,
            "client_secret": StravaConfig.clientSecret,
            "code":          code,
            "grant_type":    "authorization_code",
        ]
        let response = try await postTokenRequest(body: body)
        persistTokens(response)
    }

    @discardableResult
    private func refreshToken(refreshToken: String) async throws -> String {
        let body: [String: String] = [
            "client_id":     StravaConfig.clientID,
            "client_secret": StravaConfig.clientSecret,
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
        ]
        let response = try await postTokenRequest(body: body)
        persistTokens(response)
        return response.accessToken
    }

    private func postTokenRequest(body: [String: String]) async throws -> StravaTokenResponse {
        var request        = URLRequest(url: StravaConfig.tokenURL)
        request.httpMethod = "POST"
        // Strava's token endpoint expects application/x-www-form-urlencoded,
        // not JSON. Sending JSON with client_id as a string causes a 400 error.
        request.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")

        let formBody = body
            .map { k, v in
                let ek = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
                let ev = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
                return "\(ek)=\(ev)"
            }
            .joined(separator: "&")
        request.httpBody = formBody.data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse else { throw StravaError.apiError }

        if http.statusCode != 200 {
            // Surface the actual Strava error so it's diagnosable
            if let stravaErr = try? JSONDecoder().decode(StravaAPIError.self, from: data),
               let msg = stravaErr.displayMessage {
                throw StravaError.apiMessage("Strava: \(msg)")
            }
            throw StravaError.apiError
        }

        return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
    }

    private func persistTokens(_ response: StravaTokenResponse) {
        KeychainHelper.save(response.accessToken,       for: StravaKeys.accessToken)
        KeychainHelper.save(response.refreshToken,      for: StravaKeys.refreshToken)
        KeychainHelper.save(String(response.expiresAt), for: StravaKeys.expiresAt)

        let name = response.athlete.displayName
        UserDefaults.standard.set(name,                    forKey: UDKeys.athleteName)
        UserDefaults.standard.set(response.athlete.id,     forKey: UDKeys.athleteID)

        isConnected = true
        athleteName = name
    }

    // MARK: - Activity fetch

    private func fetchActivities(after: Date,
                                  token: String) async throws -> [StravaActivity] {
        var components      = URLComponents(url: StravaConfig.activitiesURL,
                                            resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "50"),
            URLQueryItem(name: "after",    value: String(Int(after.timeIntervalSince1970))),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                throw StravaError.notAuthenticated
            }
            throw StravaError.apiError
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([StravaActivity].self, from: data)
    }

    // MARK: - Match activities to plan days

    private func computeMatches(activities: [StravaActivity],
                                 plans: [SavedPlan]) {
        let cal  = Calendar.current
        let runs = activities.filter { $0.isRun }
        var result: [UUID: StravaActivity] = [:]

        for plan in plans {
            for week in plan.weeks {
                for day in week.days {
                    // Only match unlogged, trackable days
                    guard day.isTrackable,
                          day.completionStatus == .notStarted
                    else { continue }

                    // Find runs on the same calendar day
                    guard let match = runs.first(where: {
                        cal.isDate($0.startDate, inSameDayAs: day.date)
                    }) else { continue }

                    result[day.id] = match
                }
            }
        }

        matches = result
    }
}

// MARK: - Errors

enum StravaError: Error {
    case notAuthenticated
    case invalidCallback
    case sessionFailed
    case apiError
    case apiMessage(String)  // Strava returned a readable error body
}

// MARK: - Strava API error body

/// Decodable shape of Strava's error response.
/// e.g. {"message":"Bad Request","errors":[{"resource":"Application","field":"client_id","code":"invalid"}]}
private struct StravaAPIError: Decodable {
    let message : String?
    let errors  : [FieldError]?

    struct FieldError: Decodable {
        let resource : String?
        let field    : String?
        let code     : String?
    }

    /// Human-readable summary of the first error.
    var displayMessage: String? {
        if let e = errors?.first,
           let resource = e.resource, let code = e.code {
            return "\(resource) \(e.field ?? "") \(code)"
        }
        return message
    }
}

// MARK: - Presentation context (ASWebAuthenticationSession)

extension StravaService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        // ASWebAuthenticationSession calls this on the main thread.
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            ?? UIWindow()
        }
    }
}
