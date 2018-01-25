//
//  Dictionary.swift
//  Forth
//
//  Created by Sebastian Boettcher on 18.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

// Each dictionary entry has the following header.
//
//   Pointer to previous dictionary entry
//     ^
//     |         Flags
//     |         ^
//     |         |   Length of name            Here starts the definition, tcfa points here
//     |         |   ^                         |
//     |         |   |                         v
//   +---------+---+---+---+---+---+---+---+---+--- - -
//   | LINK    | x | 4 | T | E | S | T | 0 | 0 |
//   +---------+---+---+---+---+---+---+---+---+--- - -
//     ^                \------v------/ \--v--/
//     |                      Name       Padding to the next 4 byte boundary
//     |
//   LATEST or next dictionary entry
//
//
// Native implementations only have a dictionary entry consisting of a header; also the link address is a key
// in the code dictionary, where the block that will be executed is stored.
//
// Forth implementations are preceeded by a list of addresses and terminated by a marker (0xFFFFFFFF)
//
// +--------+---------+--- - - - ---+---------+---------+
// | HEADER | DOCOL   |     ...     | EXIT    | MARKER  |
// +--------+---------+--- - - - ---+---------+---------+
//

class Dictionary {

    struct Flags {
        static let none: Char = 0x00
        static let immediate: Char = 0x80
        static let dirty: Char = 0x40
        static let hidden: Char = 0x20
    }

    static let marker: Cell = Int32(bitPattern: UInt32.max)

    private let memory: Memory
    private var code: [Cell: Code] = [:]

    init(memory: Memory) {
        self.memory = memory
        self.latest = 0
    }

    var latest: Cell {
        set {
            self.memory[Address.latest] = newValue
        }
        get {
            return self.memory[Address.latest]
        }
    }

    func code(of word: Cell) -> Code? {
        return self.code[word]
    }

    func isHidden(word: Cell) -> Bool {
        return (self.memory[word + Memory.Size.cell] & Flags.hidden) == Flags.hidden
    }

    func isImmediate(word: Cell) -> Bool {
        return (self.memory[word + Memory.Size.cell] & Flags.immediate) == Flags.immediate
    }

    func isDirty(word: Cell) -> Bool {
        return (self.memory[word + Memory.Size.cell] & Flags.dirty) == Flags.dirty
    }

    func toggleHidden(word: Cell) {
        self.memory[word + Memory.Size.cell] ^= Flags.hidden
    }

    func toggleImmediate(word: Cell) {
        self.memory[word + Memory.Size.cell] ^= Flags.immediate
    }

    func toggleDirty(word: Cell) {
        self.memory[word + Memory.Size.cell] ^= Flags.dirty
    }

    func id(of word: Cell) -> [Char] {
        let length: Char = self.memory[word + Memory.Size.cell + Memory.Size.char]
        return self.memory[Text(address: word + Memory.Size.cell + Memory.Size.char + Memory.Size.char, length: Cell(length))]
    }

    func find(_ name: [Char]) -> Cell {
        var word = self.latest
        while word != 0 {
            let label = self.id(of: word)
            if label == name && !isHidden(word: word) {
                return word
            }
            word = self.memory[word]
        }
        return 0
    }

    func see(at address: inout Cell, base: Cell) -> String {
        let word = self.memory[address] as Cell
        let name = String(ascii: self.id(of: self.cfat(at: word)))
        var result = ""
        switch name {
        case "ENTER":
            // ignore ENTER, is implied by :
            break
        case "'":
            // print the following instruction as a name
            address += Memory.Size.cell
            result = " \(name) \(String(ascii: self.id(of: self.cfat(at: self.memory[address]))))"
        case "LIT":
            // print only the following instruction as a number
            address += Memory.Size.cell
            result = " \(String(self.memory[address] as Cell, radix: Int(base)))"
        case "BRANCH", "0BRANCH":
            // print the name and the following instruction as a number
            address += Memory.Size.cell
            result = " \(String(self.memory[address] as Cell, radix: Int(base)))"
        case "LITSTRING":
            // get the following instructions as a length and the content of a string
            address += Memory.Size.cell
            let length = self.memory[address] as Cell
            result = " S\" \(String(ascii: self.memory[Text(address: address + Memory.Size.cell, length: length)]))\""
            address = Memory.align(address: address + length)
        case "EXIT":
            // omit exit, if it is the last word
            if self.memory[address + Memory.Size.cell] != Dictionary.marker {
                result = " \(name)"
            }
        default:
            result = " \(name)"
        }
        address += Memory.Size.cell
        return result
    }

    func see(word: Cell, base: Cell) -> String {
        var result = ": \(String(ascii: self.id(of: word)))\(self.isImmediate(word: word) ? " IMMEDIATE" : "")"
        var address = self.tcfa(word: word)

        if self.code(of: address) != nil {
            return result + " ;"
        }

        while true {
            if self.memory[address] == Dictionary.marker {
                return result + " ;"
            }
            result += self.see(at: &address, base: base)
        }
    }

    func words() -> [String] {
        var result = Set<String>()
        var word = self.latest
        while word != 0 {
            if !self.isHidden(word: word) {
                result.insert(String(ascii: self.id(of: word)))
            }
            word = self.memory[word]
        }
        return Array(result).sorted()
    }

    /// gets the first cell to be executed for a colon definition
    func tcfa(word: Cell) -> Cell {
        let length: Char = self.memory[word + Memory.Size.cell + Memory.Size.char]
        return Memory.align(address: word + Memory.Size.cell + Memory.Size.char + Memory.Size.char + Cell(length))
    }

    // gets the link pointer for any address pointing somewhere in a colon definition
    func cfat(at address: Cell) -> Cell {
        var word = self.latest
        while word != 0 {
            if word < address {
                return word
            }
            word = self.memory[word]
        }
        return 0
    }

    func removeLatest() {
        if self.latest == 0 {
            return
        }
        self.memory.here = self.latest
        self.latest = self.memory[self.latest]
    }

    func create(word name: [Char], immediate: Bool) -> Cell {
        let link = self.memory.here

        self.memory.append(cell: self.latest)
        self.memory.append(byte: immediate ? Flags.immediate : Flags.none)
        self.memory.append(byte: Char(name.count))
        self.memory.append(bytes: name)
        self.memory.append(bytes: [Char](repeating: 0, count: Int(Memory.align(address: self.memory.here) - self.memory.here)))

        self.latest = link
        return self.memory.here
    }

    func define(word name: String, immediate: Bool = false, code: @escaping Code) -> Cell {
        let here = self.create(word: name.ascii, immediate: immediate)
        self.code[here] = code
        return here
    }

    func define(word name: String, immediate: Bool = false, words: [Cell]) -> Cell {
        let here = self.create(word: name.ascii, immediate: immediate)
        words.forEach {
            self.memory.append(cell: $0)
        }
        self.memory.append(cell: Dictionary.marker)
        return here
    }

    func define(variable name: String, value: Cell? = nil, address: Cell? = nil, stack: Stack) -> Cell {
        var location: Cell
        if let address = address {
            location = address
            if let value = value {
                self.memory[location] = value
            }
        } else {
            location = self.memory.here
            if let value = value {
                self.memory.append(cell: value)
            }
        }
        return self.define(word: name) {
            try stack.push(location)
        }
    }

    func define(constant name: String, value: Cell, stack: Stack) -> Cell {
        return self.define(word: name) {
            try stack.push(value)
        }
    }
}
