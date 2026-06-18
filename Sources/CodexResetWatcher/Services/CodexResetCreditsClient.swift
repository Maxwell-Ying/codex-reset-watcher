import Foundation

struct CodexResetCreditsClient: Sendable {
    var codexHome: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
    var endpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!

    func fetch() async throws -> ResetCreditsResponse {
        let auth = try loadAuth()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(auth.tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("CODEX", forHTTPHeaderField: "OAI-Product-Sku")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accountId = accountId(from: auth.tokens.accessToken, fallback: auth.tokens.accountId) {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResetCreditsError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ResetCreditsError.httpStatus(httpResponse.statusCode, body)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ResetCreditsResponse.self, from: data)
    }

    private func loadAuth() throws -> CodexAuth {
        let authURL = resolvedCodexHome().appending(path: "auth.json")
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw ResetCreditsError.missingAuth(authURL.path)
        }

        let data = try Data(contentsOf: authURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CodexAuth.self, from: data)
        } catch {
            throw ResetCreditsError.invalidAuth(authURL.path)
        }
    }

    private func resolvedCodexHome() -> URL {
        if let value = ProcessInfo.processInfo.environment["CODEX_HOME"], !value.isEmpty {
            return URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
        }
        return codexHome
    }

    private func accountId(from token: String, fallback: String?) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = Data(base64URLString: String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let auth = json["https://api.openai.com/auth"] as? [String: Any]
        else {
            return fallback
        }

        return auth["chatgpt_account_id"] as? String ?? fallback
    }
}

enum ResetCreditsError: LocalizedError {
    case missingAuth(String)
    case invalidAuth(String)
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case let .missingAuth(path):
            return "Could not find Codex login at \(path). Open Codex Desktop and sign in first."
        case let .invalidAuth(path):
            return "Could not read Codex login at \(path). Open Codex Desktop and sign in again."
        case .invalidResponse:
            return "The Codex reset endpoint returned an invalid response."
        case let .httpStatus(status, body):
            if status == 401 || status == 403 {
                return "Codex rejected the saved login. Open Codex Desktop and sign in again."
            }
            return body.isEmpty ? "The Codex reset endpoint returned HTTP \(status)." : "The Codex reset endpoint returned HTTP \(status): \(body)"
        }
    }
}
