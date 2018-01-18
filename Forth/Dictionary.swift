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

    func flags(of word: Cell) -> Byte {
        return self.memory[word + Memory.Size.cell] & ~Flags.lenmask
    }

    func name(of word: Cell) -> [Byte] {
        let flags: Byte = self.memory[word + Memory.Size.cell]
        return self.memory[Text(address: word + Memory.Size.cell + Memory.Size.byte, length: flags & Flags.lenmask)]
    }

    func word(having address: Cell) -> Cell {
        // get the latest just before address
        var word = self.latest
        while word != 0 {
            if word < address {
                return word
            }
            word = self.memory[word]
        }
        return 0
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
            if label == name && (flags(of: word) & Flags.hidden) != Flags.hidden {
                return word
            }
            word = self.memory[word]
        }
        return 0
    }

    func decompile(word: Cell) -> String {
        let immediate = (self.flags(of: word) & Flags.immediate) == Flags.immediate
        var result = "\(String(ascii: self.name(of: word))) \( (immediate ? "IMMEDIATE " : ""))"

        var address = self.tcfa(word: word)
        if let _ = self.code(of: address) {
            return result + "<native> ;"
        }
        while true {
            let word = self.memory[address] as Cell
            if word == Dictionary.marker {
                return result
            }
            let name = String(ascii: self.name(of: self.word(having: word)))
            switch name {
            case ":":
                // prepend docol if existing
                result = ": " + result
            case "'":
                // print the following instruction as a name
                address += Memory.Size.cell
                result += "\(name) \(String(ascii: self.name(of: self.word(having: self.memory[address])))) "
            case "LIT", "BRANCH", "0BRANCH":
                // print the following instruction as a number
                address += Memory.Size.cell
                result += "\(name) \(self.memory[address] as Cell) "
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
            if (flags(of: word) & Flags.hidden) != Flags.hidden {
                result.insert(String(ascii: self.name(of: word)))
            }
            word = self.memory[word]
        }
        return Array(result).sorted()
    }

    func tcfa(word: Cell) -> Cell {
        let length = Cell(self.memory[word + Memory.Size.cell] & Flags.lenmask)
        return word + Memory.Size.cell + Memory.Size.byte + length
    }

    func create(word name: [Byte], immediate: Bool) -> Cell {
        let link = self.memory.here

        self.memory.append(cell: self.latest)
        self.memory.append(byte: (Byte(name.count) & Flags.lenmask) | (immediate ? Flags.immediate : Flags.none))
        self.memory.append(bytes: name)

        self.latest = link
        return self.memory.here
    }

    private func create(word name: String, immediate: Bool) -> Cell {
        return create(word: name.ascii, immediate: immediate)
    }

    func define(word name: String, immediate: Bool = false, code: @escaping Code) -> Cell {
        let here = self.create(word: name, immediate: immediate)
        self.code[here] = code
        return here
    }

    func define(word name: String, immediate: Bool = false, words: [Cell]) -> Cell {
        
        let here = self.create(word: name, immediate: immediate)
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

