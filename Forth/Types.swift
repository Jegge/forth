//
//  Types.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

typealias Address = UInt16
typealias Cell = Int16
typealias Index = Int
typealias Byte = UInt8

struct Flags {
    static let none: Byte = 0x00
    static let immediate: Byte = 0x80
    static let hidden: Byte = 0x20
    static let lenmask: Byte = 0x1f
}
