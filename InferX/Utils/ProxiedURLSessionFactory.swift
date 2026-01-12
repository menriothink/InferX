//
//  ProxiedURLSessionFactory.swift
//  InferX
//
//  Created by mingdw on 2025/7/5.
//

import Foundation

struct URLSessionFactory {
    static let defaultTimeout: TimeInterval = 30
    static func makeSession(proxyHost: String? = nil, proxyPort: UInt32? = nil) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default

        if let host = proxyHost, let port = proxyPort, !host.isEmpty {
            print("🔧 Configuring URLSession with proxy: \(host):\(port)")
            #if os(macOS)
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: 1,
                kCFNetworkProxiesHTTPProxy: host,
                kCFNetworkProxiesHTTPPort: port,
                kCFNetworkProxiesHTTPSEnable: 1,
                kCFNetworkProxiesHTTPSProxy: host,
                kCFNetworkProxiesHTTPSPort: port
            ]
            #else
            print("⚠️ Proxy configuration is only supported on macOS builds.")
            #endif
        } else {
            print("🔧 Configuring URLSession without proxy.")
        }

        configuration.timeoutIntervalForRequest = defaultTimeout
        return configuration
    }
}
