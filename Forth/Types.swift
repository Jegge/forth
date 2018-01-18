//
//  Types.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

typealias Cell = Int32
typealias Byte = UInt8
typealias Code = (() throws -> Void)

struct Flags {
    static let none: Byte = 0x00
    static let immediate: Byte = 0x80
    static let hidden: Byte = 0x20
    static let lenmask: Byte = 0x1f
}

struct Address {
    static let here: Cell = 0
    static let latest: Cell = 4
    static let state: Cell = 8
    static let buffer: Cell = 12
    static let rstack: Cell = 512
    static let pstack: Cell = 1024
    static let dictionary: Cell = 1024
}

struct State {
    static let immediate: Cell = 0
    static let compile: Cell = 1
}

extension Character {
    static let space: Byte = 32
    static let newline: Byte = 10
    static let backslash: Byte = 92
}

struct Constants {
    static let wordlen: Int = 32
    static let forthMachineVersion: Cell = 1
}
