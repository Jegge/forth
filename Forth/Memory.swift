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
    private var data: Data = Data()

    init (chunk: Cell) {
        self.chunk = chunk
        self.here = Cell(MemoryLayout<Cell>.size)
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
        if address >= self.data.count - (MemoryLayout<Cell>.size + 1) {
            self.data.append(Data(count: Int(self.chunk)))
        }
    }

    subscript (address: Cell) -> Cell {
        get {
            if address < 0 || address > self.data.count - 1 {
                return 0
            }
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
            self.growIfNeededToReach(address: address)
            self.data[Int(address + 0)] = Byte((newValue >> 24) & 0x000000FF)
            self.data[Int(address + 1)] = Byte((newValue >> 16) & 0x000000FF)
            self.data[Int(address + 2)] = Byte((newValue >> 8) & 0x000000FF)
            self.data[Int(address + 3)] = Byte((newValue & 0x000000FF))
        }
    }

    subscript (address: Cell) -> Byte {
        get {
            if address < 0 || address > self.data.count - 1 {
                return 0
            }
           return self.data[Int(address)]
        }
        set {
            if address < 0 {
                return
            }
            self.growIfNeededToReach(address: address)
            self.data[Int(address)] = newValue
        }
    }


//    subscript (address: Cell) -> [Byte] {
//        get {
//            var buffer: [Byte] = []
//            for index in 0..<length {
//                buffer.append(self.data[address + Cell(index)])
//            }
//            return buffer
//        }
//        set {
//            for index in 0..<bytes.count {
//                self.data[address + Cell(index)] = bytes[index]
//            }
//        }
//    }

    func append(byte: Byte) {
        self[self.here] = byte
        self.here += Cell(MemoryLayout<Byte>.size)
    }

    func append(cell: Cell) {
        self[self.here] = cell
        self.here += Cell(MemoryLayout<Cell>.size)
    }

    func append(bytes: [Byte]) {
        bytes.forEach { self.append(byte: $0) }
    }

    func align () {
        while here % Cell(MemoryLayout<Cell>.size) != 0 {
            self.append(byte: 0)
        }
    }

/*
    func insert(byte: Byte) {
        self.set(byte: byte, at: self.here)
        self.here += Address(MemoryLayout<Byte>.size)
    }
    func insert(address: Address) {
        self.set(address: address, at: self.here)
        self.here += Address(MemoryLayout<Address>.size)
    }
    func insert(cell: Cell) {
        self.set(cell: cell, at: self.here)
        self.here += Address(MemoryLayout<Cell>.size)
    }
    func insert(string: String) {
        for char in Array(string.utf8) {
            self.insert(byte: char)
        }
    }
    func insert(bytes count: Address) -> Address {
        let address = self.here
        for _ in 0..<count {
            self.insert(byte: 0)
        }
        return address
    }

    func runNative(at address: Address) throws -> Bool {
        if let block = self.natives[address] {
            try block()
            return true
        }
        return false
    }

    func defineWord(name: String, link: Address, immediate: Bool = false, code: @escaping Block) -> Address {

        /*   pointer to previous word
            ^
            |
         +--|------+---+---+---+---+---+---+---+
         | LINK    | 6 | D | O | U | B | L | E |
         +---------+---+---+---+---+---+---+---+
            ^       len                        |
            |                                  V
            LINK in next word                  this address can be looked up in the natives dictionary to get the code block
         */

        let address = self.here
        self.insert(address: link)
        self.insert(byte: (Byte(name.count) & Flags.lenmask) | (immediate ? Flags.immediate : Flags.none))
        self.insert(string: name)
        self.natives[self.here] = code
        return address
    }

    func defineWord(name: String, link: Address, immediate: Bool = false, words: [Address]) -> Address {

        /*  pointer to previous word
            ^
            |
         +--|------+---+---+---+---+---+---+---+------------+------------+------------+------------+
         | LINK    | 6 | D | O | U | B | L | E | DOCOL      | DUP        | +          | EXIT       |
         +---------+---+---+---+---+---+---+---+------------+--|---------+------------+------------+
            ^       len                                        |
            |                                                  V
            LINK in next word                                  points to codeword of DUP
         */

        let address = self.here
        self.insert(address: link)
        self.insert(byte: (Byte(name.count) & Flags.lenmask) | (immediate ? Flags.immediate : Flags.none))
        self.insert(string: name)
        for word in words {
            self.insert(address: word)
        }
        return address
    }

    func defineVariable(name: String, link: Address, stack: Stack, value: Address = 0) -> Address {
        let address = self.here
        self.insert(address: value)
        return self.defineWord(name: name, link: link) {
            try stack.push(address: address)
        }
    }

    func defineConstant(name: String, link: Address, cell: Cell, stack: Stack) -> Address {
        return self.defineWord(name: name, link: link) {
            try stack.push(cell: cell)
        }
    }
    func defineConstant(name: String, link: Address, address: Address, stack: Stack) -> Address {
        return self.defineWord(name: name, link: link) {
            try stack.push(address: address)
        }
    }
    func defineConstant(name: String, link: Address, byte: Byte, stack: Stack) -> Address {
        return self.defineWord(name: name, link: link) {
            try stack.push(address: Address(byte))
        }
    }
    
    func cfa(_ address: Address) -> Address {
        // returns address of codeword for given LINK
        let len = self.get(byteAt: address + Address(MemoryLayout<Address>.size)) & Flags.lenmask
        return address + Address(MemoryLayout<Address>.size) + Address(len) + 1
    }
*/
    func dump (from: Cell, to: Cell) {
        var address: Cell = from
        let count = 16
        print("       ", separator: "", terminator: "")
        for index in (0..<count) {
            print(String(format: "| %3d   ", index), separator: "", terminator: "")
        }
        print()
        print("---------", separator: "", terminator: "")
        for _ in (0..<count) {
            print("--------", separator: "", terminator: "")
        }
        print()

        while address < to {
            print(String(format: "% 6d ", address), separator: "", terminator: "")
            for index in (0..<count) {
                let b: Byte = self[address + Cell(index)]
                print(String(format: "| %3d ", b), separator: "", terminator: "")
                if b > 31 && b < 127 {
                    print(String(format: "%c ", b), separator: "", terminator: "")
                } else {
                    print("  ", separator: "", terminator: "")
                }
            }
            print()
            address += Cell(count)
        }
    }
 }
