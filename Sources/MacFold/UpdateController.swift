import AppKit
import Foundation

/// Checks the public GitHub release feed. It deliberately does not replace the
/// application bundle: safe in-place installation requires the signed appcast
/// and Developer ID setup documented in AUTO_UPDATE_CHECKLIST.md.
@MainActor
final class UpdateController: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable
        case failed
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var latestVersion: String?
    @Published private(set) var releaseURL: URL?

    private let currentVersion: String
    private static let releasesURL = URL(string: "https://api.github.com/repos/satyalayatinasish-arch/Mac-Fold/releases")!
    private static let lastCheckKey = "lastUpdateCheck"

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        let draft: Bool
        let prerelease: Bool

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft
            case prerelease
        }
    }

    init(currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0") {
        self.currentVersion = currentVersion
    }

    func checkIfDue() {
        guard UserDefaults.standard.bool(forKey: "isAutomaticUpdateChecks") else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= 24 * 60 * 60 else { return }
        checkForUpdates()
    }

    func checkForUpdates() {
        guard status != .checking else { return }
        status = .checking
        Task {
            do {
                var request = URLRequest(url: Self.releasesURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("MacFold/(self.currentVersion)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let releases = try JSONDecoder().decode([Release].self, from: data)
                guard let latest = releases.first(where: { !$0.draft && !$0.prerelease }) else {
                    self.status = .upToDate
                    return
                }
                self.latestVersion = latest.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                self.releaseURL = latest.htmlURL
                self.status = Self.isNewer(self.latestVersion ?? "0.0.0", than: self.currentVersion)
                    ? .updateAvailable
                    : .upToDate
                UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
            } catch {
                self.status = .failed
            }
        }
    }

    func openLatestRelease() {
        guard let releaseURL else { return }
        NSWorkspace.shared.open(releaseURL)
    }

    private static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}
