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
    static let rstack: Cell = 512
    static let pstack: Cell = 1024
    static let dictionary: Cell = 1024
}

let forthMachineVersion: Cell = 1
