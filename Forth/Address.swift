//
//  Address.swift
//  Forth
//
//  Created by Sebastian Boettcher on 26.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

// Memory layout:
//
// 0x0000   +---------------------------+
//          | System variables          |
// 0x002C   +---------------------------+
//          | Line buffer               |
// 0x012C   +---------------------------+
//          | Return stack top          |
//          |                           |
//          | Return stack bottom       |
// 0x1000   +---------------------------+
//          | Parameter stack top       |
//          |                           |
//          | Parameter stack bottom    |
// 0x2000   +---------------------------+
//          |                           |
//          | Dictionary                |
//          |                           |
//          .                           .
//          .                           .

struct Address {
    static let here: Cell = 0
    static let latest: Cell = Memory.Size.cell * 1
    static let state: Cell = Memory.Size.cell * 2
    static let base: Cell = Memory.Size.cell * 3
    static let trace: Cell = Memory.Size.cell * 4
    static let r0: Cell = Memory.Size.cell * 5
    static let s0: Cell = Memory.Size.cell * 6
    static let xt0: Cell = Memory.Size.cell * 7
    static let xt1: Cell = Memory.Size.cell * 8
    static let ip0: Cell = Memory.Size.cell * 9
    static let ip1: Cell = Memory.Size.cell * 10
    static let buffer: Cell = Memory.Size.cell * 11 // 256
    static let rstack: Cell = Memory.Size.cell * 1024
    static let pstack: Cell = Memory.Size.cell * 2048

    static let rstackSize: Cell = Memory.Size.cell * (1024 - 96)
    static let pstackSize: Cell = Memory.Size.cell * 1024
    static let bufferSize: Cell = Memory.Size.char * 256
    static let padOffset: Cell = Memory.Size.cell * 64
    static let outOffset: Cell = Memory.Size.cell * 256

    static let dictionary: Cell = Memory.Size.cell * 2048
}
