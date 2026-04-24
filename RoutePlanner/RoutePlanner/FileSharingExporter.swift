import UIKit

struct FileShareHelper {
    static func shareGPX(_ gpx: String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("route.gpx")

        try? gpx.write(to: url, atomically: true, encoding: .utf8)

        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .rootViewController?
            .present(vc, animated: true)
    }
}
