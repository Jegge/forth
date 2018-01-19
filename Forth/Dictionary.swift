//
//  Dictionary.swift
//  Forth
//
//  Created by Sebastian Boettcher on 18.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

class Dictionary {

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
        return ((self.memory[word + Memory.Size.cell] & ~Flags.lenmask) & Flags.hidden) == Flags.hidden
    }
    func isImmediate(word: Cell) -> Bool {
        return ((self.memory[word + Memory.Size.cell] & ~Flags.lenmask) & Flags.immediate) == Flags.immediate
    }

    func name(of word: Cell) -> [Byte] {
        let flags: Byte = self.memory[word + Memory.Size.cell]
        return self.memory[Text(address: word + Memory.Size.cell + Memory.Size.byte, length: Cell(flags & Flags.lenmask))]
    }

    func word(after word: Cell) -> Cell {
        var pointer = self.latest
        while pointer != 0 {
            if self.memory[pointer] == word {
                return pointer
            }
            pointer = self.memory[pointer]
        }
        return 0
    }

    func find(byName name: [Byte]) -> Cell {
        var word = self.latest
        while word != 0 {
            let label = self.name(of: word)
            if label == name && !isHidden(word: word) {
            //if label == name && (flags(of: word) & Flags.hidden) != Flags.hidden {
                return word
            }
            word = self.memory[word]
        }
        return 0
    }

    func decompile(word: Cell) -> String {
        var result = "\(String(ascii: self.name(of: word))) \(self.isImmediate(word: word) ? "IMMEDIATE " : "")"

        var address = self.tcfa(word: word)
        if let _ = self.code(of: address) {
            return result + "<native> ;"
        }
        while true {
            let word = self.memory[address] as Cell
            if word == Dictionary.marker {
                return result
            }
            let name = String(ascii: self.name(of: self.cfat(at: word)))
            switch name {
            case "ENTER":
                // prepend docol if existing
                result = ": " + result
            case "'":
                // print the following instruction as a name
                address += Memory.Size.cell
                result += "\(name) \(String(ascii: self.name(of: self.cfat(at: self.memory[address])))) "
            case "LIT", "BRANCH", "0BRANCH":
                // print the following instruction as a number
                address += Memory.Size.cell
                result += "\(name) \(self.memory[address] as Cell) "
            case "LITSTRING":
                // get the following instructions as a length and the content of a string
                address += Memory.Size.cell
                let length = self.memory[address] as Cell
                result += "\(name) \(length) \(String(ascii: self.memory[Text(address: address + Memory.Size.cell, length: length)])) "
                address = Memory.align(address: address + length)
            case "EXIT":
                // write the last exit as ;
                if self.memory[address + Memory.Size.cell] != Dictionary.marker {
                    result += "\(name) "
                } else {
                    result += ";"
                }
            default:
                result += "\(name) "
            }
            address += Memory.Size.cell
        }
    }

    func words () -> [String] {
        var result = Set<String>()
        var word = self.latest
        while word != 0 {
            if !self.isHidden(word: word) {
                result.insert(String(ascii: self.name(of: word)))
            }
            word = self.memory[word]
        }
        return Array(result).sorted()
    }

    /// gets the first cell to be executed for a colon definition
    func tcfa(word: Cell) -> Cell {
        let length = Cell(self.memory[word + Memory.Size.cell] & Flags.lenmask)
        return Memory.align(address: word + Memory.Size.cell + Memory.Size.byte + length)
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

    func create(word name: [Byte], immediate: Bool) -> Cell {
        let link = self.memory.here

        self.memory.append(cell: self.latest)
        self.memory.append(byte: (Byte(name.count) & Flags.lenmask) | (immediate ? Flags.immediate : Flags.none))
        self.memory.append(bytes: name)
        self.memory.append(bytes: Array<Byte>(repeating: 0, count: Int(Memory.align(address: self.memory.here) - self.memory.here)))

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

