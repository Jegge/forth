//
//  Dictionary.swift
//  Forth
//
//  Created by Sebastian Boettcher on 18.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

class Dictionary {

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

    func link(for address: Cell) -> Cell {
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

    func find(byName name: [Byte]) -> Cell {
        var word = self.latest
        while word != 0 {
            let label = self.name(of: word)
            if label == name {
                return word
            }
            word = self.memory[word]
        }
        return 0
    }

    func words() -> [String] {
        var list: [String] = []
        var word = self.latest
        while word != 0 {
            list.append(String(ascii: self.name(of: word)))
            word = self.memory[word]
        }
        return list
    }

    func tcfa(link: Cell) -> Cell {
        let length = Cell(self.memory[link + Memory.Size.cell] & Flags.lenmask)
        let padding =  Cell(Memory.Size.cell - ((length + Memory.Size.byte) % Memory.Size.cell))
        return link + Memory.Size.cell + Memory.Size.byte + length + padding
    }

    func create(word name: [Byte], immediate: Bool) -> Cell {
        self.memory.align()

        let link = self.memory.here

        self.memory.append(cell: self.latest)
        self.memory.append(byte: (Byte(name.count) & Flags.lenmask) | (immediate ? Flags.immediate : Flags.none))
        self.memory.append(bytes: name)
        self.memory.align()

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

