//
//  String+Extensions.swift
//  InferX
//
//  Created by mingdw on 2025/6/29.
//

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
    
    func displayName() -> String {
        let afterProvider = self.components(separatedBy: "::").last ?? self
        let afterOrg = afterProvider.components(separatedBy: "/").last ?? afterProvider
        return afterOrg
    }
}
