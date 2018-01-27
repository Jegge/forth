//
//  Extensions.swift
//  Forth
//
//  Created by Sebastian Boettcher on 18.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

extension String {
    init (ascii bytes: [Char]) {
        self = String(bytes: bytes, encoding: String.Encoding.ascii)!
    }
    var ascii: [Char] {
        return unicodeScalars.filter { $0.isASCII }.map { Char($0.value) }
    }

    func padLeft (toLength: Int, withPad: Character) -> String {
        return String(repeating: withPad, count: max(toLength - self.count, 0)) + self
    }
}

extension Character {
    var ascii: Char? {
        let value = String(self).unicodeScalars.filter { $0.isASCII }.first?.value
        return value != nil ? Char(value!) : nil
    }

    static let tab: Char = 9
    static let space: Char = 32
    static let newline: Char = 10
    static let backslash: Char = 92
    static let dash: Char = 45
    static let delete: Char = 127
    static let zero: Char = 48
}
