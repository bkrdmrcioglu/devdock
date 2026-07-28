import Foundation

/// Checks public GitHub Releases on `devdock` for a newer DevDock zip.
enum UpdateChecker {
    static let brewUpgradeCommand = "brew upgrade --cask bkrdmrcioglu/devdock/devdock"
    static let siteURL = URL(string: "https://github.com/bkrdmrcioglu/devdock")!
    static let releasesPageURL = URL(string: "https://github.com/bkrdmrcioglu/devdock/releases")!

    private static let apiURL = URL(
        string: "https://api.github.com/repos/bkrdmrcioglu/devdock/releases/latest"
    )!

    struct ReleaseInfo: Equatable {
        let version: String
        let tag: String
        let downloadURL: URL?
        let releasePageURL: URL?
    }

    enum Outcome: Equatable {
        case upToDate(current: String)
        case available(ReleaseInfo)
        case failed(String)
    }

    static func check(currentVersion: String = AppInfo.shortVersion) async -> Outcome {
        var request = URLRequest(url: apiURL, timeoutInterval: 12)
        request.setValue("DevDock/\(currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return .failed("GitHub \(http.statusCode)")
            }
            guard let info = parseRelease(data: data) else {
                return .failed("Could not parse release")
            }
            if isNewer(info.version, than: currentVersion) {
                return .available(info)
            }
            return .upToDate(current: currentVersion)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Semantic-ish compare: `1.2.10` > `1.2.9`. Ignores leading `v`.
    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = versionParts(remote)
        let l = versionParts(local)
        let count = max(r.count, l.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    static func normalizeVersion(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("v") {
            s = String(s.dropFirst())
        }
        if let space = s.firstIndex(of: " ") {
            s = String(s[..<space])
        }
        return s
    }

    // MARK: - Private

    private static func versionParts(_ raw: String) -> [Int] {
        normalizeVersion(raw)
            .split(separator: ".")
            .map { part in
                let digits = part.prefix(while: { $0.isNumber })
                return Int(digits) ?? 0
            }
    }

    private static func parseRelease(data: Data) -> ReleaseInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let tag = (json["tag_name"] as? String) ?? ""
        let version = normalizeVersion(tag.isEmpty ? (json["name"] as? String ?? "") : tag)
        guard !version.isEmpty else { return nil }

        var download: URL?
        if let assets = json["assets"] as? [[String: Any]] {
            let zip = assets.first { asset in
                let name = (asset["name"] as? String)?.lowercased() ?? ""
                return name.hasSuffix(".zip") && name.contains("devdock")
            } ?? assets.first { (($0["name"] as? String)?.lowercased() ?? "").hasSuffix(".zip") }
            if let urlString = zip?["browser_download_url"] as? String {
                download = URL(string: urlString)
            }
        }

        let page: URL?
        if let html = json["html_url"] as? String {
            page = URL(string: html)
        } else {
            page = releasesPageURL
        }

        return ReleaseInfo(
            version: version,
            tag: tag.isEmpty ? "v\(version)" : tag,
            downloadURL: download,
            releasePageURL: page
        )
    }
}
