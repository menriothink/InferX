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
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: 1,
                kCFNetworkProxiesHTTPProxy: host,
                kCFNetworkProxiesHTTPPort: port,
                kCFNetworkProxiesHTTPSEnable: 1,
                kCFNetworkProxiesHTTPSProxy: host,
                kCFNetworkProxiesHTTPSPort: port
            ]
        } else {
            print("🔧 Configuring URLSession without proxy.")
        }

        configuration.timeoutIntervalForRequest = defaultTimeout
        return configuration
    }
}
