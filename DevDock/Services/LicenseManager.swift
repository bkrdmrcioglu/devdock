import Foundation

enum LicenseLimits {
    static let freeProjectCap = 3
    static let buyURL = URL(string: "https://devdock.lemonsqueezy.com")!
}

@MainActor
final class LicenseManager: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var licenseKeyMasked: String = ""
    @Published private(set) var customerEmail: String = ""
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var isBusy: Bool = false
    @Published var draftKey: String = ""

    private let keyStorage = "devdock.license.key"
    private let instanceStorage = "devdock.license.instance"
    private let emailStorage = "devdock.license.email"
    private let proStorage = "devdock.license.isPro"

    private var storedKey: String? {
        get { UserDefaults.standard.string(forKey: keyStorage) }
        set { UserDefaults.standard.set(newValue, forKey: keyStorage) }
    }

    private var instanceID: String? {
        get { UserDefaults.standard.string(forKey: instanceStorage) }
        set { UserDefaults.standard.set(newValue, forKey: instanceStorage) }
    }

    init() {
        isPro = UserDefaults.standard.bool(forKey: proStorage)
        if let key = storedKey {
            draftKey = key
            licenseKeyMasked = Self.mask(key)
        }
        customerEmail = UserDefaults.standard.string(forKey: emailStorage) ?? ""
        if isPro, storedKey != nil {
            statusMessage = "Pro active"
            Task { await refreshValidation() }
        } else {
            statusMessage = "Free plan · \(LicenseLimits.freeProjectCap) projects"
        }
    }

    func activate() async {
        let key = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            statusMessage = "Paste your Lemon Squeezy license key."
            return
        }

        isBusy = true
        statusMessage = "Activating…"
        defer { isBusy = false }

        let instanceName = Host.current().localizedName ?? "DevDock Mac"
        do {
            let response = try await LicenseAPI.activate(licenseKey: key, instanceName: instanceName)
            guard response.activated else {
                statusMessage = response.error ?? "Activation failed."
                clearProLocally()
                return
            }
            storedKey = key
            instanceID = response.instance?.id
            if let email = response.meta?.customer_email {
                customerEmail = email
                UserDefaults.standard.set(email, forKey: emailStorage)
            }
            licenseKeyMasked = Self.mask(key)
            setPro(true)
            statusMessage = "Pro activated · thanks!"
        } catch {
            statusMessage = error.localizedDescription
            clearProLocally()
        }
    }

    func deactivate() async {
        guard let key = storedKey else {
            clearProLocally()
            statusMessage = "Free plan"
            return
        }
        isBusy = true
        statusMessage = "Deactivating…"
        defer { isBusy = false }

        do {
            if let instanceID {
                _ = try await LicenseAPI.deactivate(licenseKey: key, instanceID: instanceID)
            }
        } catch {
            // Still clear locally so the user can move machines
            statusMessage = "Local deactivate · \(error.localizedDescription)"
        }
        clearProLocally()
        draftKey = ""
        statusMessage = "Back to Free plan"
    }

    func refreshValidation() async {
        guard let key = storedKey else { return }
        do {
            let response = try await LicenseAPI.validate(licenseKey: key, instanceID: instanceID)
            if response.valid {
                setPro(true)
                statusMessage = "Pro active"
            } else {
                clearProLocally()
                statusMessage = response.error ?? "License no longer valid."
            }
        } catch {
            // Offline grace: keep Pro if we previously activated
            if isPro {
                statusMessage = "Pro (offline)"
            }
        }
    }

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: proStorage)
    }

    private func clearProLocally() {
        setPro(false)
        storedKey = nil
        instanceID = nil
        licenseKeyMasked = ""
        customerEmail = ""
        UserDefaults.standard.removeObject(forKey: emailStorage)
    }

    private static func mask(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "••••" }
        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(4)
        return "\(prefix)…\(suffix)"
    }
}

// MARK: - Lemon Squeezy License API (public, no store API key in app)

enum LicenseAPI {
    struct ActivateResponse: Decodable {
        let activated: Bool
        let error: String?
        let instance: Instance?
        let meta: Meta?
    }

    struct ValidateResponse: Decodable {
        let valid: Bool
        let error: String?
        let meta: Meta?
    }

    struct DeactivateResponse: Decodable {
        let deactivated: Bool
        let error: String?
    }

    struct Instance: Decodable {
        let id: String
    }

    struct Meta: Decodable {
        let customer_email: String?
    }

    static func activate(licenseKey: String, instanceName: String) async throws -> ActivateResponse {
        try await post(
            path: "/v1/licenses/activate",
            fields: [
                "license_key": licenseKey,
                "instance_name": instanceName,
            ],
            as: ActivateResponse.self
        )
    }

    static func validate(licenseKey: String, instanceID: String?) async throws -> ValidateResponse {
        var fields = ["license_key": licenseKey]
        if let instanceID { fields["instance_id"] = instanceID }
        return try await post(path: "/v1/licenses/validate", fields: fields, as: ValidateResponse.self)
    }

    static func deactivate(licenseKey: String, instanceID: String) async throws -> DeactivateResponse {
        try await post(
            path: "/v1/licenses/deactivate",
            fields: [
                "license_key": licenseKey,
                "instance_id": instanceID,
            ],
            as: DeactivateResponse.self
        )
    }

    private static func post<T: Decodable>(path: String, fields: [String: String], as: T.Type) async throws -> T {
        var request = URLRequest(url: URL(string: "https://api.lemonsqueezy.com\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { key, value in
                "\(urlEncode(key))=\(urlEncode(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode >= 400 {
            if let parsed = try? JSONDecoder().decode(ActivateResponse.self, from: data),
               let message = parsed.error {
                throw NSError(domain: "LemonSqueezy", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: message,
                ])
            }
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "LemonSqueezy", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: text,
            ])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B") ?? value
    }
}
