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

    private (set) var here: Address = 0

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
    func get(byteAt addr: Address) -> Byte {
        return self.data[Int(addr)]
    }
    func get(addressAt addr: Address) -> Address{
        return Address(self.data[Int(addr)]) << 8 | Address(self.data[Int(addr + 1)])
    }
    func get(cellAt addr: Address) -> Cell {
        return Cell(bitPattern: self.get(addressAt: addr))
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
         +--|------+---+---+---+---+---+---+---+---+------------+
         | LINK    | 6 | D | O | U | B | L | E | 0 | NATIVE     |
         +---------+---+---+---+---+---+---+---+---+------------+
            ^       len                         pad  codeword
            |                                      ^
            LINK in next word                      this address can be looked up in the natives dictionary to get the code block
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
         +--|------+---+---+---+---+---+---+---+---+------------+------------+------------+------------+
         | LINK    | 6 | D | O | U | B | L | E | 0 | DOCOL      | DUP        | +          | EXIT       |
         +---------+---+---+---+---+---+---+---+---+------------+--|---------+------------+------------+
            ^       len                         pad  codeword      |
            |                                                      V
            LINK in next word                                      points to codeword of DUP
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

    func cfa(_ address: Address) -> Address {
        // returns address of codeword for given LINK
        let len = self.get(byteAt: address + Address(MemoryLayout<Address>.size)) & Flags.lenmask
        return address + Address(MemoryLayout<Address>.size) + Address(len) + 1
    }

    func dump (cap: Address = Address.max) {
        var address: Address = 0
        let count = 16
        print("       | ", separator: "", terminator: "")
        for index in (0..<count) {
            print(String(format: "% 4d ", index), separator: "", terminator: "")
        }
        print()
        print("---------", separator: "", terminator: "")
        for _ in (0..<count) {
            print("-----", separator: "", terminator: "")
        }
        print()

        while address < cap {
            print(String(format: "% 6d | ", address), separator: "", terminator: "")
            for index in (0..<count) {
                let b = self.get(byteAt: address + Address(index))
                if b > 31 && b < 127 {
                    print(String(format: "% 4c ", b), separator: "", terminator: "")
                } else {
                    print(String(format: "% 4d ", b), separator: "", terminator: "")
                }
            }
            print()
            address += Address(count)
        }
    }
 }
