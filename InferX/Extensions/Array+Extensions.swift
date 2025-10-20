//
//  Array+Extensions.swift
//  InferX
//
//  Created by mingdw on 2025/9/14.
//

extension Array {
    func uniqued<T: Hashable>(on keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
