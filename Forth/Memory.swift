//
//  Memory.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

// p self.memory.dump(from: Address.dictionary, to: Address.dictionary + self.latest + 32)
class Memory {

    private let chunk: Cell
    private var data: Data = Data()

    struct Size {
        static let cell = Cell(MemoryLayout<Cell>.size)
        static let byte = Cell(MemoryLayout<Byte>.size)
    }

    init (chunk: Cell) {
        self.chunk = chunk
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

    private func growIfNeededToReach(address: Cell) {
        if address >= Int32(self.data.count) - (Memory.Size.cell + 1) {
            self.data.append(Data(count: Int(self.chunk)))
        }
    }

    subscript (address: Cell) -> Cell {
        get {
            if address < 0 {
                return 0
            }
            self.growIfNeededToReach(address: address + Memory.Size.cell)
            let a = Cell(self.data[Int(address + 0)]) << 24
            let b = Cell(self.data[Int(address + 1)]) << 16
            let c = Cell(self.data[Int(address + 2)]) << 8
            let d = Cell(self.data[Int(address + 3)])
            return a | b | c | d
        }
        set {
            if address < 0 {
                return
            }
            self.growIfNeededToReach(address: address + Memory.Size.cell)

            self.data[Int(address + 0)] = Byte((newValue >> 24) & 0x000000FF)
            self.data[Int(address + 1)] = Byte((newValue >> 16) & 0x000000FF)
            self.data[Int(address + 2)] = Byte((newValue >> 8) & 0x000000FF)
            self.data[Int(address + 3)] = Byte((newValue & 0x000000FF))
        }
    }

    subscript (address: Cell) -> Byte {
        get {
            if address < 0 {
                return 0
            }
            self.growIfNeededToReach(address: address + Memory.Size.byte)

            return self.data[Int(address)]
        }
        set {
            if address < 0 {
                return
            }
            self.growIfNeededToReach(address: address + Memory.Size.byte)

            self.data[Int(address)] = newValue
        }
    }

    subscript (text: Text) -> [Byte] {
        get {
            if text.address < 0 {
                return []
            }
            self.growIfNeededToReach(address: text.address + (Cell(text.length) * Memory.Size.byte))

            var bytes: [Byte] = []
            for index in 0..<Int(text.length) {
                bytes.append(self.data[index + Int(text.address)])
            }
            return bytes
        }
        set {
            if text.address < 0 {
                return
            }
            self.growIfNeededToReach(address: text.address + (Cell(text.length) * Memory.Size.byte))

            for index in 0..<Int(text.length) {
                self.data[index + Int(text.address)] = newValue[index]
            }
        }
    }

    func append(byte: Byte) {
        self[self.here] = byte
        self.here += Memory.Size.byte
    }

    func append(cell: Cell) {
        self[self.here] = cell
        self.here += Memory.Size.cell
    }

    func append(bytes: [Byte]) {
        bytes.forEach { self.append(byte: $0) }
    }

    func dump (address: Cell, length: Cell) -> String {
        var result = ""
        var index = address
        while index < address + length {

            result += String(format: "% 8X", index)
            for i in 0..<16 {
                result += String(format: "% 3X", self[Cell(index) + Cell(i)] as Byte)
            }
            for i in 0..<16 {
                let character = self[Cell(index) + Cell(i)] as Byte
                if character >= Character.space && character < Character.delete {
                    result += String(format: "%c", character)
                } else {
                    result += "."
                }
            }
            index += 16
            result += "\n"
        }
        return result
    }

//    func dump (from: Cell, to: Cell) {
//        var address: Cell = from
//        let count = 16
//        print("       ", separator: "", terminator: "")
//        for index in (0..<count) {
//            print(String(format: "| %3d   ", index), separator: "", terminator: "")
//        }
//        print()
//        print("---------", separator: "", terminator: "")
//        for _ in (0..<count) {
//            print("--------", separator: "", terminator: "")
//        }
//        print()
//
//        while address < to {
//            print(String(format: "% 6d ", address), separator: "", terminator: "")
//            for index in (0..<count) {
//                let b: Byte = self[address + Cell(index)]
//                print(String(format: "| %3d ", b), separator: "", terminator: "")
//                if b > 31 && b < 127 {
//                    print(String(format: "%c ", b), separator: "", terminator: "")
//                } else {
//                    print("  ", separator: "", terminator: "")
//                }
//            }
//            print()
//            address += Cell(count)
//        }
//    }
}

