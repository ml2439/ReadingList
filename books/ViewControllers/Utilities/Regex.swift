//
//  Regex.swift
//  books
//
//  Created by Andrew Bennet on 26/01/2018.
//  Copyright © 2018 Andrew Bennet. All rights reserved.
//

import Foundation

class Regex {
    
    static func IsMatch(pattern: String, input: String) -> Bool {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.count))
        return !matches.isEmpty
    }
    
    // Adapted from http://samwize.com/2016/07/21/how-to-capture-multiple-groups-in-a-regex-with-swift/
    static func CapturedGroups(pattern: String, input: String) -> [String] {
        
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.count))
        guard let match = matches.first else { return [] }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return [] }
        
        return (1...lastRangeIndex).map{ (input as NSString).substring(with: match.range(at: $0)) }
    }
}
