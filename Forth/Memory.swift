//
//  Memory.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

class Memory {

    private var natives: [Address: Block] = [:]
    private var data = Data(count: Int(Address.max))

    init () {
        self.here = 2
    }
    private (set) var here: Address {
        set {
            self.set(address: newValue, at: 0)
        }
        get {
            return self.get(addressAt: 0)
        }
    }

    func set(byte: Byte, at addr: Address) {
        self.data[Int(addr)] = byte
    }
    func set(address: Address, at addr: Address) {
        self.data[Int(addr)] = Byte(address >> 8)
        self.data[Int(addr + 1)] = Byte(address & 0x00ff)
    }
    func set(cell: Cell, at addr: Address) {
        self.set(address: Address(bitPattern:cell), at: addr)
    }
    func set(bytes: [Byte], at addr: Address) {
        for index in 0..<bytes.count {
            self.set(byte: bytes[index], at: addr + Address(index))
        }
    }
    func set(string: String, at addr: Address) {
        self.set(bytes: Array(string.utf8), at: addr)
    }
    func get(byteAt addr: Address) -> Byte {
        return self.data[Int(addr)]
    }
    func get(addressAt addr: Address) -> Address {
        return Address(self.data[Int(addr)]) << 8 | Address(self.data[Int(addr + 1)])
    }
    func get(cellAt addr: Address) -> Cell {
        return Cell(bitPattern: self.get(addressAt: addr))
    }
    func get(bytesAt addr: Address, length: Cell) -> [Byte] {
        var buffer: [Byte] = []
        for index in 0..<length {
            buffer.append(self.get(byteAt: addr + Address(index)))
        }
        return buffer
    }

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

    func dump (cap: Address = Address.max) {
        var address: Address = 0
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

        while address < cap {
            print(String(format: "% 6d ", address), separator: "", terminator: "")
            for index in (0..<count) {
                let b = self.get(byteAt: address + Address(index))
                print(String(format: "| %3d ", b), separator: "", terminator: "")
                if b > 31 && b < 127 {
                    print(String(format: "%c ", b), separator: "", terminator: "")
                } else {
                    print("  ", separator: "", terminator: "")
                }

            }
            print()
            address += Address(count)
        }
    }
 }
