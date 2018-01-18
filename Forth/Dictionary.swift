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

    func code(for word: Cell) -> Code? {
        return self.code[word]
    }

    private func define(word name: String, immediate: Bool) -> Cell {
        let link = self.memory.here

        self.memory.append(cell: self.latest)
        self.memory.append(byte: (Byte(name.count) & Flags.lenmask) | (immediate ? Flags.immediate : Flags.none))
        self.memory.append(bytes: name.ascii)
        self.memory.align()

        self.latest = link
        return self.memory.here
    }

    func define(word name: String, immediate: Bool = false, code: @escaping Code) -> Cell {

        let here = self.define(word: name, immediate: immediate)
        self.code[here] = code
        return here
    }

    func define(word name: String, immediate: Bool = false, words: [Cell]) -> Cell {
        
        let here = self.define(word: name, immediate: immediate)
        words.forEach {
            self.memory.append(cell: $0)
        }
        return here
    }


}

