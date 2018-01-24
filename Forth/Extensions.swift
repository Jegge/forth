//
//  Extensions.swift
//  Forth
//
//  Created by Sebastian Boettcher on 18.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

extension String {
    init (ascii bytes: [Byte]) {
        self = String(bytes: bytes, encoding: String.Encoding.ascii)!
    }
    var ascii: [Byte] {
        return unicodeScalars.filter { $0.isASCII }.map { Byte($0.value) }
    }

    func padLeft (toLength: Int, withPad: Character) -> String {
        return String(repeating: withPad, count: max(toLength - self.count, 0)) + self
    }
}

extension Character {
    var ascii: Byte? {
        let value = String(self).unicodeScalars.filter { $0.isASCII }.first?.value
        return value != nil ? Byte(value!) : nil
    }

    static let tab: Byte = 9
    static let space: Byte = 32
    static let newline: Byte = 10
    static let backslash: Byte = 92
    static let dash: Byte = 45
    static let delete: Byte = 127
}
