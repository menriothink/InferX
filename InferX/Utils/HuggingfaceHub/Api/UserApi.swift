//
//  User.swift
//  HuggingfaceHub
//
//  Created by John Mai on 2024/11/7.
//

import Foundation

extension HFApi {
    public func whoami(token: String? = nil) async throws -> User {
        let url = URL(string: "\(endpoint)/api/whoami-v2")!

        var request = URLRequest(url: url)
        let headers = buildHFHeaders(token: token)

        request.allHTTPHeaderFields = headers
        return try await httpClient.send(request: request, with: User.self)
    }
}

public struct User: Codable, Sendable {
    let type: String
    let id: String
    let name: String
    let fullname: String
    let email: String
    let emailVerified: Bool
    let canPay: Bool
    let periodEnd: Int
    let isPro: Bool
    let avatarUrl: String
    let orgs: [Organization]
    let auth: Auth
}

public struct Organization: Codable, Sendable {
    let type: String
    let id: String
    let name: String
    let fullname: String
    let email: String?
    let canPay: Bool
    let periodEnd: Int?
    let avatarUrl: String
    let roleInOrg: String
    let isEnterprise: Bool
}

public struct Auth: Codable, Sendable {
    let type: String
    let accessToken: AccessToken?
}

public struct AccessToken: Codable, Sendable {
    let displayName: String
    let role: String
    let createdAt: String
}
