//
//  Memory.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

class Memory {

    private let chunk: Cell
    private let max: Cell
    private var data: Data = Data()

    struct Size {
        static let cell = Cell(MemoryLayout<Cell>.size)
        static let char = Cell(MemoryLayout<Char>.size)
    }

    init (chunk: Cell, max: Cell) {
        self.chunk = chunk
        self.max = max
        self.here = Memory.Size.cell
    }

    var here: Cell {
        set {
            self[Address.here] = newValue
        }
        get {
            return self[Address.here]
        }
    }

    var unused: Cell {
        return (self.max - self.here) / Memory.Size.cell
    }

    static func align(address: Cell) -> Cell {
        return (address + (Memory.Size.cell - 1)) & ~(Memory.Size.cell - 1)
    }

    private func ensureSizeFor(address: Cell) -> Bool {
        if address >= self.max {
            return false
        }
        if address >= self.data.count - 1 {
            let size = (address - Cell(self.data.count))
            let bytes = ((size / self.chunk) + 1) * self.chunk
            self.data.append(Data(count: Int(bytes)))
        }
        return true
    }

    subscript (address: Cell) -> Cell {
        get {
            if address < 0 {
                return 0
            }
            if !self.ensureSizeFor(address: address + Memory.Size.cell) {
                return 0
            }

            // swiftlint:disable identifier_name
            let a = Cell(self.data[Int(address + 0)]) << 24
            let b = Cell(self.data[Int(address + 1)]) << 16
            let c = Cell(self.data[Int(address + 2)]) << 8
            let d = Cell(self.data[Int(address + 3)])
            // swiftlint:enable identifier_name
            return a | b | c | d
        }
        set {
            if address < 0 {
                return
            }
            if !self.ensureSizeFor(address: address + Memory.Size.cell) {
                return
            }
            self.data[Int(address + 0)] = Char((newValue >> 24) & 0x000000FF)
            self.data[Int(address + 1)] = Char((newValue >> 16) & 0x000000FF)
            self.data[Int(address + 2)] = Char((newValue >> 8) & 0x000000FF)
            self.data[Int(address + 3)] = Char((newValue & 0x000000FF))
        }
    }

    subscript (address: Cell) -> Char {
        get {
            if address < 0 {
                return 0
            }
            if !self.ensureSizeFor(address: address + Memory.Size.char) {
                return 0
            }
            return self.data[Int(address)]
        }
        set {
            if address < 0 {
                return
            }
            if !self.ensureSizeFor(address: address + Memory.Size.char) {
                return
            }
            self.data[Int(address)] = newValue
        }
    }

    subscript (text: Text) -> [Char] {
        get {
            if text.address < 0 {
                return []
            }
            if !self.ensureSizeFor(address: text.address + (Cell(text.length) * Memory.Size.char)) {
                return []
            }
            var bytes: [Char] = []
            for index in 0..<Int(text.length) {
                bytes.append(self.data[index + Int(text.address)])
            }
            return bytes
        }
        set {
            if text.address < 0 {
                return
            }
            if !self.ensureSizeFor(address: text.address + (Cell(text.length) * Memory.Size.char)) {
                return
            }
            for index in 0..<Int(text.length) {
                self.data[index + Int(text.address)] = newValue[index]
            }
        }
    }

    func append(byte: Char) {
        self[self.here] = byte
        self.here += Memory.Size.char
    }

    func append(cell: Cell) {
        self[self.here] = cell
        self.here += Memory.Size.cell
    }

    func append(bytes: [Char]) {
        bytes.forEach { self.append(byte: $0) }
    }

    func dump(address: Cell, length: Cell) -> String {
        var result = ""
        var index = address
        while index < address + length {

            result += String(format: "% 8X |", index)

            for offset in 0..<16 {
                if offset != 0 && offset % 4 == 0 {
                    result += "  "
                }
                if Int(index) + Int(offset) < address + length {
                    result += String(format: "% 3X", self[Cell(index) + Cell(offset)] as Char)
                } else {
                    result += "   "
                }
            }

            result += " | "

            for offset in 0..<16 {
                if offset != 0 && offset % 4 == 0 {
                    result += " "
                }
                if Int(index) + Int(offset) < address + length {
                    let character = self[Cell(index) + Cell(offset)] as Char
                    if character >= Character.space && character < Character.delete {
                        result += String(format: "%c", character)
                    } else {
                        result += "."
                    }
                }
            }

            index += 16
            result += "\n"
        }
        return result
    }
}
