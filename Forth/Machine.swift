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
    private var nextIp: Cell = 0  // next instruction pointer

    var state: Cell {
        set {
            self.memory[Address.state] = newValue
        }
        get {
            return self.memory[Address.state]
        }
    }

    var base: Cell {
        set {
            self.memory[Address.base] = newValue
        }
        get {
            return self.memory[Address.base]
        }
    }

    var trace: Cell {
        set {
            self.memory[Address.trace] = newValue
        }
        get {
            return self.memory[Address.trace]
        }
    }

    init (system: SystemProvided, chunk: Cell = 4096) {
        self.system = system
        self.memory = Memory(chunk: chunk)
        self.pstack = Stack(memory: self.memory, address: Address.pstack, size: 512, addressAddress: Address.s0)
        self.rstack = Stack(memory: self.memory, address: Address.rstack, size: 256, addressAddress: Address.r0)
        self.memory.here = Address.dictionary
        self.dictionary = Dictionary(memory: self.memory)

        _ = self.dictionary.define(variable: "HERE", address: Address.here, stack: self.pstack)
        _ = self.dictionary.define(variable: "STATE", value: State.immediate, address: Address.state, stack: self.pstack)
        let latest = self.dictionary.define(variable: "LATEST", address: Address.latest, stack: self.pstack)
        _ = self.dictionary.define(variable: "BASE", value: 10, address: Address.base, stack: self.pstack)
        _ = self.dictionary.define(variable: "TRACE", value: 0, address: Address.trace, stack: self.pstack)
        _ = self.dictionary.define(variable: "S0", address: Address.s0, stack: self.pstack)

        _ = self.dictionary.define(constant: "VERSION", value: Constants.version, stack: self.pstack)
        let rz = self.dictionary.define(constant: "R0", value: Address.r0, stack: self.pstack)
        _ = self.dictionary.define(constant: "F_IMMED", value: Cell(Flags.immediate), stack: self.pstack)
        _ = self.dictionary.define(constant: "F_HIDDEN", value: Cell(Flags.hidden), stack: self.pstack)
        _ = self.dictionary.define(constant: "F_LENMASK", value: Cell(Flags.lenmask), stack: self.pstack)

        let docol = self.dictionary.define(word: ":") {
            try self.rstack.push(self.oldIp)
        }

        _ = self.dictionary.define(constant: "DOCOL", value: docol, stack: self.pstack)

        let exit = self.dictionary.define(word: ";") {
            self.nextIp = try self.rstack.pop()
        }
        let lit = self.dictionary.define(word: "LIT") {
            self.next()
            try self.pstack.push(self.memory[self.nextIp])
        }
        _ = self.dictionary.define(word: "DROP") {
            _ = try self.pstack.pop()
        }
        _ = self.dictionary.define(word: "SWAP") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v2)
            try self.pstack.push(v1)
        }
        _ = self.dictionary.define(word: "DUP") {
            let v = try self.pstack.pop()
            try self.pstack.push(v)
            try self.pstack.push(v)
        }
        _ = self.dictionary.define(word: "OVER") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1)
            try self.pstack.push(v2)
            try self.pstack.push(v1)
        }
        _ = self.dictionary.define(word: "ROT") {
            let v3 = try self.pstack.pop()
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v2)
            try self.pstack.push(v3)
            try self.pstack.push(v1)
        }
        _ = self.dictionary.define(word: "-ROT") {
            let v3 = try self.pstack.pop()
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v3)
            try self.pstack.push(v1)
            try self.pstack.push(v2)
        }
        _ = self.dictionary.define(word: "2DROP") {
            _ = try self.pstack.pop()
            _ = try self.pstack.pop()
        }
        _ = self.dictionary.define(word: "2DUP") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1)
            try self.pstack.push(v2)
            try self.pstack.push(v1)
            try self.pstack.push(v2)
        }
        _ = self.dictionary.define(word: "2SWAP") {
            let v4 = try self.pstack.pop()
            let v3 = try self.pstack.pop()
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v3)
            try self.pstack.push(v4)
            try self.pstack.push(v1)
            try self.pstack.push(v2)
        }
        _ = self.dictionary.define(word: "?DUP") {
            let v = try self.pstack.pop()
            try self.pstack.push(v)
            if v != 0 {
                try self.pstack.push(v)
            }
        }
        _ = self.dictionary.define(word: "1+") {
            try self.pstack.push(try self.pstack.pop() + 1)
        }
        _ = self.dictionary.define(word: "1-") {
            try self.pstack.push(try self.pstack.pop() - 1)
        }
        let inc4 = self.dictionary.define(word: "4+") {
            try self.pstack.push(try self.pstack.pop() + 4)
        }
        _ = self.dictionary.define(word: "4-") {
            try self.pstack.push(try self.pstack.pop() - 4)
        }
        _ = self.dictionary.define(word: "+") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 + v2)
        }
        _ = self.dictionary.define(word: "-") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 - v2)
        }
        let mult = self.dictionary.define(word: "*") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 * v2)
        }
        _ = self.dictionary.define(word: "/MOD") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 % v2)
            try self.pstack.push(v1 / v2)
        }
        _ = self.dictionary.define(word: "=") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 == v2 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "<>") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 != v2 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "<") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 < v2 ? 1 : 0)
        }
        _ = self.dictionary.define(word: ">") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 > v2 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "<=") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 <= v2 ? 1 : 0)
        }
        _ = self.dictionary.define(word: ">=") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 >= v2 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "0=") {
            let v = try self.pstack.pop()
            try self.pstack.push(v == 0 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "0<>") {
            let v = try self.pstack.pop()
            try self.pstack.push(v != 0 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "0<") {
            let v = try self.pstack.pop()
            try self.pstack.push(v < 0 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "0>") {
            let v = try self.pstack.pop()
            try self.pstack.push(v > 0 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "0<=") {
            let v = try self.pstack.pop()
            try self.pstack.push(v <= 0 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "0>=") {
            let v = try self.pstack.pop()
            try self.pstack.push(v >= 0 ? 1 : 0)
        }
        _ = self.dictionary.define(word: "AND") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 & v2)
        }
        _ = self.dictionary.define(word: "OR") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 | v2)
        }
        _ = self.dictionary.define(word: "XOR") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 ^ v2)
        }
        _ = self.dictionary.define(word: "INVERT") {
            let v = try self.pstack.pop()
            try self.pstack.push(~v)
        }
        _ = self.dictionary.define(word: "SYS-EXIT") {
            self.system.exit(try self.pstack.pop())
        }
        _ = self.dictionary.define(word: "EMIT") {
            let character = try self.pstack.pop()
            self.system.print(String(format:"%c", character), error: false)
        }
        _ = self.dictionary.define(word: "KEY") {
            try self.pstack.push(Cell(self.key()))
        }
        let word = self.dictionary.define(word: "WORD") {
            let text = self.word()
            try self.pstack.push(text.address)
            try self.pstack.push(Cell(text.length))
        }
        _ = self.dictionary.define(word: "CHAR") {
            let text = self.word()
            if text.length < 1 {
                throw RuntimeError.expectedWord
            }
            try self.pstack.push(self.memory[text.address])
        }
        let find = self.dictionary.define(word: "FIND") {
            let text = self.word()
            let name = self.memory[text]
            let link = self.dictionary.find(byName: name)
            try self.pstack.push(link)
        }
        let toimmediate = self.dictionary.define(word: "[", immediate: true) {
            self.state = State.immediate
        }
        let tocompile = self.dictionary.define(word: "]") {
            self.state = State.compile
        }
        _ = self.dictionary.define(word: "!") {
            let address = try self.pstack.pop()
            let value = try self.pstack.pop()
            self.memory[address] = value
        }
        _ = self.dictionary.define(word: "@") {
            let address = try self.pstack.pop()
            let cell: Cell = self.memory[address]
            try self.pstack.push(cell)
        }
        _ = self.dictionary.define(word: ">R") {
            try self.rstack.push(try self.pstack.pop())
        }
        _ = self.dictionary.define(word: "R>") {
            try self.pstack.push(try self.rstack.pop())
        }
        _ = self.dictionary.define(word: "RSP@") {
            try self.pstack.push(self.rstack.pointer)
        }
        let rspstore = self.dictionary.define(word: "RSP!") {
            self.rstack.pointer = try self.pstack.pop()
        }
        _ = self.dictionary.define(word: "RDROP") {
            _ = try self.rstack.pop()
        }
        _ = self.dictionary.define(word: "DSP@") {
            try self.pstack.push(self.pstack.pointer)
        }
        _ = self.dictionary.define(word: "DSP!") {
            self.pstack.pointer = try self.pstack.pop()
        }
        let tcfa = self.dictionary.define(word: ">CFA") {
            let address = try self.pstack.pop()
            try self.pstack.push(self.dictionary.tcfa(link: address))
        }
        _ = self.dictionary.define(word: ">DFA", words: [ docol, tcfa, inc4, exit ])
        
        _ = self.dictionary.define(word: "IMMEDIATE", immediate: true) {
            self.memory[self.dictionary.latest + 4] ^= Flags.immediate
        }
        let hidden = self.dictionary.define(word: "HIDDEN") {
            self.memory[try self.pstack.pop() + 4] ^= Flags.hidden
        }
        _ = self.dictionary.define(word: "HIDE", words: [ docol, word, find, hidden, exit ])
        
        let create = self.dictionary.define(word: "CREATE") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            let name = self.memory[Text(address: address, length: Byte(length))]
            _ = self.dictionary.create(word: name, immediate: false)
        }
        let branch = self.dictionary.define(word: "BRANCH") {
            self.nextIp += 1
            self.nextIp += self.memory[self.nextIp]
        }
        _ = self.dictionary.define(word: "0BRANCH") {
            self.nextIp += 1
            let offset: Cell = self.memory[self.nextIp]
            if  try self.pstack.pop() == 0 {
                self.nextIp += offset
            }
        }
        _ = self.dictionary.define(word: "'") {
            self.nextIp += 1
            let word: Cell = self.memory[self.nextIp]
            try self.pstack.push(word)
        }
        let comma = self.dictionary.define(word: ",") {
            self.memory.append(cell: try self.pstack.pop())
        }
        _ = self.dictionary.define(word: "NUMBER") {
            // TODO
        }
        _ = self.dictionary.define(word: ":", words: [ docol, word, create, lit, docol, comma, latest, hidden, tocompile, exit ])
        _ = self.dictionary.define(word: ";", immediate: true, words: [ docol, lit, exit, comma, latest, hidden, toimmediate, exit ])

        let interpret = self.dictionary.define(word: "INTERPRET") {

            let text = self.word()
            let name = self.memory[text]
            let link = self.dictionary.find(byName: name)

            if link != 0 { // it's in the dictionary
                let cfa = self.dictionary.tcfa(link: link)
                if self.state == State.immediate || (self.dictionary.flags(for: link) & Flags.immediate == Flags.immediate) {
                    self.nextIp = cfa
                } else {
                    self.memory.append(cell: cfa)
                }
            }

            let (result, unconverted) = self.number(text)
            if unconverted == 0 { // it's a number
                if self.state == State.immediate {
                    try self.pstack.push(result)
                } else {
                    self.memory.append(cell: lit)
                    self.memory.append(cell: result)
                }
            }

            throw RuntimeError.parseError(name)


//            // we change the course of action by directly switching the appropriate instruction in
//            // the QUIT word. We initialize it with IGNORE, but if we find something to execute immediatly
//            // we replace IGNORE with whatever needs to be executed
//
//            self.dictionary[quitRef].instructions[2] = .word(ignore)
//
//            let word = self.word()
//            let index = self.dictionary.find(word)
//            //print(" --- INTERPRET read '\(word)' -> \(index)")
//
//            if index != -1 { // it's in the dictionary
//                if self.state == State.immediate || self.dictionary[index].immediate {
//                    self.dictionary[quitRef].instructions[2] = .word(index)
//                } else {
//                    self.dictionary[self.dictionary.latest].instructions.append(.word(index))
//                }
//                return
//            }
//
//            if let value = self.number(word) { // it's a number
//                if self.state == State.immediate {
//                    self.pstack.push(value)
//                } else {
//                    self.dictionary[self.dictionary.latest].instructions.append(.word(lit))
//                    self.dictionary[self.dictionary.latest].instructions.append(.word(value))
//                }
//                return
//            }
//
//            if word != "" {
//                throw RuntimeError.parseError(word)
//            }
        }
        let quit = self.dictionary.define(word: "QUIT", words: [ rz, rspstore, interpret, branch, -8 ])


        let dot = self.dictionary.define(word: ".") {
            print(try self.pstack.pop())
        }
        let double = self.dictionary.define(word: "DOUBLE", words: [ docol, lit, 2, mult, exit ])
        let quad = self.dictionary.define(word: "QUAD", words: [ docol, double, double, exit ])
        let test = self.dictionary.define(word: "TEST", words: [ lit, 3, quad, dot ])

        self.nextIp = quit
        self.nextIp = test
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

    private func word () -> Text {
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
        let text = Text(address: Address.buffer, length: Byte(bytes.count))
        self.memory[text] = bytes

        return text 
    }

    private func number (_ text: Text) -> (Cell, Cell) {

        return (0,0)
    }

    private func next () {
        self.nextIp += Cell(MemoryLayout<Cell>.size)
        self.oldIp = self.nextIp
    }

    func run() {
//        self.memory.dump(from: Address.dictionary, to: Address.dictionary + 256)
//        print()
        while true {
            do {
                let word: Cell = self.memory[self.nextIp]
                if let code = self.dictionary.code(for: word) {
                    try code()
                    self.next()
                } else {
                    self.nextIp = word
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
