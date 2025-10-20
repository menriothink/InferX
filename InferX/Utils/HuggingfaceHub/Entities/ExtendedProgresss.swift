//
//  ExtendedProgresss.swift
//  InferX
//
//  Created by mingdw on 2025/7/9.
//

import Foundation

struct IndividualProgress {
    var progress: Progress?
    var downloadingFileName: String = ""
}

struct ExtendedProgresss {
    var totalProgress: Progress = Progress()
    var individualProgresses: [String : IndividualProgress] = [:]
}
