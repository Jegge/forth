//
//  Machine.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

class Machine {

    private var system: SystemProvided
    private var memory: Memory
    private var pstack: Stack
    private var rstack: Stack
    private var dictionary: Dictionary

    private var buffer: String? = nil
    private var oldIp: Cell = 0  // current / previous instruction pointer
    private var nxtIp: Cell = 0  // next instruction pointer

    var state: Cell {
        set {
            self.memory[Address.state] = newValue
        }
        get {
            return self.memory[Address.state]
        }
    }

    init (system: SystemProvided, chunk: Cell = 4096) {
        self.system = system
        self.memory = Memory(chunk: chunk)
        self.pstack = Stack(memory: self.memory, top: Address.pstack, size: 512)
        self.rstack = Stack(memory: self.memory, top: Address.rstack, size: 256)
        self.memory.here = Address.dictionary
        self.dictionary = Dictionary(memory: self.memory)
        self.state = State.immediate
        
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

    private func key () -> Byte {
        while true {
            if self.buffer == nil {
                self.buffer = self.system.readLine()
            }

            guard let line = self.buffer else {
                self.system.exit(0) // stdin closed
            }

            self.buffer = String(self.buffer![self.buffer!.index(after: self.buffer!.startIndex)...])
            if self.buffer!.count < 1 {
                self.buffer = nil
            }

            guard let character = line.first?.ascii else {
                continue
            }

            return character
        }
    }

    private func word () -> (address: Cell, length: Cell) {
        var buffer: [Byte] = []
        var character: Byte = 0

        // skip spaces and comments
        while (true) {
            character = self.key()
            while character == Character.space {
                character = self.key()
            }
            if character == Character.backslash {
                while character != Character.newline {
                    character = self.key()
                }
            } else {
                break
            }
        }

        // read word until space or newline or comment
        while character != Character.space &&
              character != Character.newline &&
              character != Character.backslash {
            buffer.append(character)
            character = self.key()
        }

        let bytes = Array(buffer[0..<Constants.wordlen])
        self.memory.set(bytes: bytes, at: Address.buffer)

        return (address: Address.buffer, length: Cell(bytes.count))
    }

    private func next () {
        self.nxtIp += Cell(MemoryLayout<Cell>.size)
        self.oldIp = self.nxtIp
    }

    func run() {
//        self.memory.dump(from: Address.dictionary, to: Address.dictionary + 256)
//        print()
        while true {
            do {
                let word: Cell = self.memory[self.nxtIp]
                if let code = self.dictionary.code(for: word) {
                    try code()
                    self.next()
                } else {
                    self.nxtIp = word
                }
            } catch {
//                self.system.print("ERROR: \(error)\n", error: false)
//                self.buffer = nil
//                self.nextip = InstructionPointer(word: self.dictionary.find("QUIT"))
            }
        }
    }

    func interrupt() {
//        self.system.print("ERROR: \(error)\n", error: false)
//        self.buffer = nil
//        self.nextip = InstructionPointer(word: self.dictionary.find("QUIT"))
    }
}
