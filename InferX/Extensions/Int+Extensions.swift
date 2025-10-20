//
//  Int+Extensions.swift
//  InferX
//
//  Created by mingdw on 2025/8/23.
//

import Foundation

extension Int {
    /// Converts an integer value representing nanoseconds into seconds (as a Double).
    ///
    /// This computed property treats the integer as a duration in nanoseconds
    /// and returns the equivalent duration in seconds.
    ///
    /// Example:
    /// ```
    /// let durationInNano = 1_500_000_000 // 1.5 billion nanoseconds
    /// let durationInSeconds = durationInNano.asSecondsFromNano // Result: 1.5
    /// ```
    var asSecondsFromNano: Double {
        return Double(self) / 1_000_000_000.0
    }
}
