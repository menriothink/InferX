//
//  JSONEncoder+Default.swift
//  
//
//  Created by Kevin Hermawan on 10/11/23.
//

import Foundation

extension JSONEncoder {
    static var `default`: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .prettyPrinted
        
        return encoder
    }
}
