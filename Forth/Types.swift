//
//  Types.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

typealias Cell = Int32
typealias UCell = UInt32
typealias Char = UInt8
typealias Code = (() throws -> Void)

struct Text {
    let address: Cell
    let length: Cell
}
