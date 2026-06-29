import Foundation

struct CodexAPIClient: Sendable {
    var codexHome: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
    var resetCreditsEndpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!
    var usageEndpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    var timeoutSeconds: TimeInterval = 20
    var perform: @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }

    func fetchResetCredits() async throws -> ResetCreditsResponse {
        try await fetchResetCredits(context: loadAuthContext())
    }

    func fetchUsage() async throws -> CodexUsageResponse {
        try await fetchUsage(context: loadAuthContext())
    }

    func fetchResetCredits(context: CodexAuthContext) async throws -> ResetCreditsResponse {
        try await fetch(ResetCreditsResponse.self, from: resetCreditsEndpoint, context: context)
    }

    func fetchUsage(context: CodexAuthContext) async throws -> CodexUsageResponse {
        try await fetch(CodexUsageResponse.self, from: usageEndpoint, context: context)
    }

    func loadAccountIdentity() throws -> CodexAccountIdentity {
        try loadAuthContext().identity
    }

    func loadAuthContext() throws -> CodexAuthContext {
        let auth = try loadAuth()
        let idTokenPayload = jwtPayload(from: auth.tokens.idToken)
        let idTokenAuth = idTokenPayload?["https://api.openai.com/auth"] as? [String: Any]
        let accessTokenAccountId = accountId(from: auth.tokens.accessToken, fallback: auth.tokens.accountId)
        let idTokenAccountId = idTokenAuth?["chatgpt_account_id"] as? String
        let resolvedAccountId = idTokenAccountId ?? accessTokenAccountId

        return CodexAuthContext(
            accessToken: auth.tokens.accessToken,
            accountId: resolvedAccountId,
            identity: CodexAccountIdentity(
                accountId: resolvedAccountId,
                email: idTokenPayload?["email"] as? String,
                name: idTokenPayload?["name"] as? String
            )
        )
    }

    private func fetch<Response: Decodable>(_ responseType: Response.Type, from endpoint: URL, context: CodexAuthContext) async throws -> Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("CODEX", forHTTPHeaderField: "OAI-Product-Sku")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accountId = context.accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw CodexAPIError.rateLimited(httpResponse.value(forHTTPHeaderField: "Retry-After"))
            }
            throw CodexAPIError.httpStatus(httpResponse.statusCode)
        }
        guard !data.isEmpty else {
            throw CodexAPIError.emptyResponse
        }
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           !contentType.localizedCaseInsensitiveContains("json") {
            throw CodexAPIError.unexpectedContentType(contentType)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data)
    }

    private func loadAuth() throws -> CodexAuth {
        let authURL = resolvedCodexHome().appending(path: "auth.json")
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexAPIError.missingAuth(authURL.path)
        }

        let data = try Data(contentsOf: authURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CodexAuth.self, from: data)
        } catch {
            throw CodexAPIError.invalidAuth(authURL.path)
        }
    }

    private func resolvedCodexHome() -> URL {
        if let value = ProcessInfo.processInfo.environment["CODEX_HOME"], !value.isEmpty {
            return URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
        }
        return codexHome
    }

    private func accountId(from token: String, fallback: String?) -> String? {
        let auth = jwtPayload(from: token)?["https://api.openai.com/auth"] as? [String: Any]
        return auth?["chatgpt_account_id"] as? String ?? fallback
    }

    private func jwtPayload(from token: String?) -> [String: Any]? {
        guard let token else {
            return nil
        }
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = Data(base64URLString: String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else {
            return nil
        }
        return json
    }
}

enum CodexAPIError: LocalizedError {
    case missingAuth(String)
    case invalidAuth(String)
    case invalidResponse
    case emptyResponse
    case unexpectedContentType(String)
    case rateLimited(String?)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case let .missingAuth(path):
            return "未找到 Codex 登录信息：\(path)。请先打开 Codex Desktop 并登录。"
        case let .invalidAuth(path):
            return "无法读取 Codex 登录信息：\(path)。请重新打开 Codex Desktop 登录。"
        case .invalidResponse:
            return "Codex 端点返回了无效响应。"
        case .emptyResponse:
            return "Codex 端点返回了空响应。"
        case let .unexpectedContentType(contentType):
            return "Codex 端点返回的是 \(contentType)，不是 JSON。请重新打开 Codex Desktop 登录。"
        case let .rateLimited(retryAfter):
            if let retryAfter, !retryAfter.isEmpty {
                return "Codex 限制了本次检查。请在 \(retryAfter) 秒后重试。"
            }
            return "Codex 限制了本次检查。请稍后重试。"
        case let .httpStatus(status):
            if status == 401 || status == 403 {
                return "Codex 拒绝了已保存的登录信息。请重新打开 Codex Desktop 登录。"
            }
            return "Codex 端点返回 HTTP \(status)。"
        }
    }
}
