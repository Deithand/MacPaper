import Foundation
import IOKit
import AppKit

/// Client-side license manager. Talks to the Python bot's FastAPI server.
///
/// Endpoints expected:
///   POST /api/activate  body: {key, hwid, app_version}
///   POST /api/validate  body: {key, hwid}
/// Both return:   {ok, key, telegram_id, username, plan, expires_at?}
///
/// Offline grace: after a successful activate/validate, the app will accept
/// the stored license for up to `offlineGraceDays` without reaching the server.
final class License {
    static let shared = License()

    // MARK: - Config (overridable via UserDefaults keys)

    /// Default server URL — change via `UserDefaults -> licenseServerURL`.
    static let defaultServerURL = "http://127.0.0.1:8787"
    /// Default bot username — change via `UserDefaults -> licenseBotUsername`.
    static let defaultBotUsername = "MacPaperLicenseBot"

    private let offlineGraceDays: Double = 7
    private let appVersion = "0.3"

    // MARK: - State

    struct Info: Codable, Equatable {
        var key: String
        var telegramID: Int64?
        var username: String?
        var plan: String
        var expiresAt: Date?
        var hwid: String
        var lastValidated: Date
    }

    private(set) var info: Info?
    var onChange: (() -> Void)?

    /// Pro gating disabled — everything is unlocked by default.
    var isLicensed: Bool { true }

    var displayUser: String {
        if let u = info?.username, !u.isEmpty { return "@" + u }
        if let id = info?.telegramID { return "id\(id)" }
        return "Pro"
    }

    var serverURL: URL {
        let s = UserDefaults.standard.string(forKey: "licenseServerURL") ?? Self.defaultServerURL
        return URL(string: s) ?? URL(string: Self.defaultServerURL)!
    }

    var botUsername: String {
        UserDefaults.standard.string(forKey: "licenseBotUsername") ?? Self.defaultBotUsername
    }

    // MARK: - Setup

    init() {
        self.info = Self.load()
    }

    // MARK: - Keychain-ish storage (UserDefaults JSON — OK for a test build)

    private static let key = "licenseInfo"

    private static func load() -> Info? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(Info.self, from: data)
    }

    private func save() {
        guard let info = info else {
            UserDefaults.standard.removeObject(forKey: Self.key); return
        }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(info) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func signOut() {
        info = nil
        save()
        onChange?()
    }

    // MARK: - Hardware ID

    static func hwid() -> String {
        let matching = IOServiceMatching("IOPlatformExpertDevice")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        defer { IOObjectRelease(service) }
        let propKey = "IOPlatformUUID" as CFString
        if let cf = IORegistryEntryCreateCFProperty(service, propKey, kCFAllocatorDefault, 0) {
            return (cf.takeRetainedValue() as? String) ?? "unknown-hwid"
        }
        return "unknown-hwid"
    }

    // MARK: - Networking

    enum LicenseError: LocalizedError {
        case network(String)
        case server(String)
        case invalidResponse
        var errorDescription: String? {
            switch self {
            case .network(let s): return "Network error: \(s)"
            case .server(let s):  return s
            case .invalidResponse: return "Invalid server response."
            }
        }
    }

    func activate(key rawKey: String, completion: @escaping (Result<Info, Error>) -> Void) {
        let key = Self.normalizeKey(rawKey)
        call(path: "/api/activate", body: ["key": key, "hwid": Self.hwid(), "app_version": appVersion]) {
            [weak self] result in
            self?.handle(result, completion: completion)
        }
    }

    func revalidate(completion: @escaping (Result<Info, Error>) -> Void) {
        guard let info = info else {
            completion(.failure(LicenseError.server("No license stored."))); return
        }
        call(path: "/api/validate", body: ["key": info.key, "hwid": Self.hwid()]) { [weak self] result in
            self?.handle(result, completion: completion)
        }
    }

    private func handle(_ result: Result<[String: Any], Error>,
                        completion: @escaping (Result<Info, Error>) -> Void) {
        DispatchQueue.main.async {
            switch result {
            case .failure(let e):
                completion(.failure(e))
            case .success(let json):
                if let ok = json["ok"] as? Bool, !ok {
                    let msg = (json["error"] as? String) ?? "License rejected."
                    completion(.failure(LicenseError.server(msg))); return
                }
                guard let key = json["key"] as? String else {
                    completion(.failure(LicenseError.invalidResponse)); return
                }
                var expires: Date?
                if let s = json["expires_at"] as? String {
                    let fmt = ISO8601DateFormatter()
                    expires = fmt.date(from: s)
                }
                let info = Info(
                    key: key,
                    telegramID: (json["telegram_id"] as? NSNumber)?.int64Value,
                    username: json["username"] as? String,
                    plan: (json["plan"] as? String) ?? "pro",
                    expiresAt: expires,
                    hwid: Self.hwid(),
                    lastValidated: Date()
                )
                self.info = info
                self.save()
                self.onChange?()
                completion(.success(info))
            }
        }
    }

    private func call(path: String, body: [String: Any],
                      completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let url = serverURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(.failure(LicenseError.network(err.localizedDescription))); return
            }
            guard let data = data,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(LicenseError.invalidResponse)); return
            }
            completion(.success(j))
        }.resume()
    }

    // MARK: - Utility

    static func normalizeKey(_ s: String) -> String {
        let up = s.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return up
    }

    func openBotBuyLink() {
        let url = URL(string: "https://t.me/\(botUsername)?start=buy")!
        NSWorkspace.shared.open(url)
    }
}
