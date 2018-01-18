//
//  Machine.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

class Machine {

    private var memory: Memory
    private var pstack: Stack
    private var rstack: Stack
    private var dictionary: Dictionary
    
    private var oldIp: Cell = 0  // current / previous instruction pointer
    private var nxtIp: Cell = 0  // next instruction pointer

    init (chunk: Cell = 4096) {
        self.memory = Memory(chunk: chunk)
        self.pstack = Stack(memory: self.memory, top: Address.pstack, size: 512)
        self.rstack = Stack(memory: self.memory, top: Address.rstack, size: 256)
        self.memory.here = Address.dictionary
        self.dictionary = Dictionary(memory: self.memory)
        
        let docol = self.dictionary.define(word: ":") {
            try self.rstack.push(self.oldIp)
        }
        let exit = self.dictionary.define(word: ";") {
            self.nxtIp = try self.rstack.pop()
        }
        let lit = self.dictionary.define(word: "LIT") {
            self.next()
            try self.pstack.push(self.memory[self.nxtIp])
        }
        let mult = self.dictionary.define(word: "*") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 * v2)
        }
        let dot = self.dictionary.define(word: ".") {
            print(try self.pstack.pop())
        }

        let double = self.dictionary.define(word: "DOUBLE", words: [ docol, lit, 2, mult, exit ])
        let quad = self.dictionary.define(word: "QUAD", words: [ docol, double, double, exit ])
        let test = self.dictionary.define(word: "TEST", words: [ lit, 3, quad, dot ])

        self.nxtIp = test
    }

    private func next () {
        self.nxtIp += Cell(MemoryLayout<Cell>.size)
        self.oldIp = self.nxtIp
    }

    func run () throws {

        self.memory.dump(from: Address.dictionary, to: Address.dictionary + 256)
        print()

        while true {
            let word: Cell = self.memory[self.nxtIp]
            if let code = self.dictionary.code(for: word) {
                try code()
                self.next()
            } else {
                self.nxtIp = word
            }
        }
    }
}
