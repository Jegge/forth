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

struct Text {
    let address: Cell
    let length: Cell
}

struct Flags {
    static let none: Byte = 0x00
    static let immediate: Byte = 0x80
    static let dirty: Byte = 0x40
    static let hidden: Byte = 0x20
}

struct Address {
    static let here: Cell = 0
    static let latest: Cell = 4
    static let state: Cell = 8
    static let base: Cell = 12
    static let trace: Cell = 16
    static let r0: Cell = 20
    static let s0: Cell = 24
    static let xt0: Cell = 28
    static let xt1: Cell = 32
    static let ip0: Cell = 36
    static let ip1: Cell = 40
    static let buffer: Cell = 44 // 256
    static let rstack: Cell = 4096
    static let pstack: Cell = 8192

    static let rstackSize: Cell = 4096 - 384
    static let pstackSize: Cell = 4096
    static let bufferSize: Cell = 256

    static let dictionary: Cell = 8192
}

struct State {
    static let immediate: Cell = 0
    static let compile: Cell = 1
}

extension Character {
    static let tab: Byte = 9
    static let space: Byte = 32
    static let newline: Byte = 10
    static let backslash: Byte = 92
    static let dash: Byte = 45
    static let delete: Byte = 127
}

struct Constants {
    static let version: Cell = 1
}
