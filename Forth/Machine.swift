//
//  Machine.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

// swiftlint:disable:next type_body_length
class Machine {

    static let version: Cell = 1

    struct State {
        static let immediate: Cell = 0
        static let compile: Cell = 1
    }

    private var system: SystemProvided
    private var memory: Memory
    private var pstack: Stack
    private var rstack: Stack
    private var dictionary: Dictionary

    private var buffer: String?         // line buffer for
    private var previousIp: Cell = 0    // previous instruction pointer
    private var currentIp: Cell = 0     // current / next instruction pointer

    private var wordQuit: Cell = 0      // dictionary address of the word QUIT
    private var wantsAbort: Bool = false

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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    init (system: SystemProvided, memory: Memory, rstack: Stack, pstack: Stack, dictionary: Dictionary) {
        self.system = system
        self.memory = memory
        self.rstack = rstack
        self.pstack = pstack
        self.dictionary = dictionary
        self.memory.here = Address.dictionary

        _ = self.dictionary.define(variable: "HERE", address: Address.here, stack: self.pstack)
        _ = self.dictionary.define(variable: "STATE", value: State.immediate, address: Address.state, stack: self.pstack)
        let latest = self.dictionary.define(variable: "LATEST", address: Address.latest, stack: self.pstack)
        _ = self.dictionary.define(variable: "BASE", value: 10, address: Address.base, stack: self.pstack)
        _ = self.dictionary.define(variable: "TRACE", value: 0, address: Address.trace, stack: self.pstack)
        _ = self.dictionary.define(variable: "S0", address: Address.s0, stack: self.pstack)
        _ = self.dictionary.define(variable: "XT0", value: 0, address: Address.xt0, stack: self.pstack)
        _ = self.dictionary.define(variable: "XT1", value: 0, address: Address.xt1, stack: self.pstack)
        _ = self.dictionary.define(variable: "IP0", value: 0, address: Address.ip0, stack: self.pstack)
        _ = self.dictionary.define(variable: "IP1", value: 0, address: Address.ip1, stack: self.pstack)

        _ = self.dictionary.define(constant: "VERSION", value: Machine.version, stack: self.pstack)
        let rz = self.dictionary.define(constant: "R0", value: Address.rstack, stack: self.pstack)
        _ = self.dictionary.define(constant: "F_IMMED", value: Cell(Dictionary.Flags.immediate), stack: self.pstack)
        _ = self.dictionary.define(constant: "F_DIRTY", value: Cell(Dictionary.Flags.dirty), stack: self.pstack)
        _ = self.dictionary.define(constant: "F_HIDDEN", value: Cell(Dictionary.Flags.hidden), stack: self.pstack)
        _ = self.dictionary.define(constant: "ENDOFWORD", value: Dictionary.marker, stack: self.pstack)

        // Pushes the instruction pointer onto the return stack
        let enter = self.dictionary.define(word: "ENTER") {
            try self.rstack.push(self.previousIp)
        }
        _ = self.dictionary.define(constant: "DOCOL", value: enter, stack: self.pstack)

        // Pops the instruction pointer from the return stack
        let exit = self.dictionary.define(word: "EXIT") {
            self.currentIp = try self.rstack.pop()
        }
        // The next instruction will be interpreted as a number literal and be pushed ( -- n )
        let lit = self.dictionary.define(word: "LIT") {
            self.next()
            try self.pstack.push(self.memory[self.currentIp])
        }
        // The next two instructions will be interpreted as the address and length of a string literal and be pushed ( -- addr length )
        _ = self.dictionary.define(word: "LITSTRING") {
            self.next()
            let length = self.memory[self.currentIp] as Cell
            let address = self.currentIp + Memory.Size.cell
            try self.pstack.push(address)
            try self.pstack.push(length)
            self.currentIp = Memory.align(address: self.currentIp + length)
        }
        // Removes the top item from the stack ( n -- )
        let drop = self.dictionary.define(word: "DROP") {
            _ = try self.pstack.pop()
        }
        // Exchanges the top items on the stack ( n1 n2 -- n2 n1 )
        _ = self.dictionary.define(word: "SWAP") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v2)
            try self.pstack.push(v1)
        }
        // Duplicates the top item on the stack ( n -- n n )
        _ = self.dictionary.define(word: "DUP") {
            let v = try self.pstack.pop()
            try self.pstack.push(v)
            try self.pstack.push(v)
        }
        // Duplicates the second item on the stack  ( n1 n2 -- n1 n2 n1 )
        _ = self.dictionary.define(word: "OVER") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1)
            try self.pstack.push(v2)
            try self.pstack.push(v1)
        }
        // Rotates the top three items on the stack right ( n1 n2 n3 -- n2 n3 n1 )
        let rot = self.dictionary.define(word: "ROT") {
            let v3 = try self.pstack.pop()
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v2)
            try self.pstack.push(v3)
            try self.pstack.push(v1)
        }
        // Rotates the top three items on the stack left ( n1 n2 n3 -- n3 n1 n2 )
        _ = self.dictionary.define(word: "-ROT") {
            let v3 = try self.pstack.pop()
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v3)
            try self.pstack.push(v1)
            try self.pstack.push(v2)
        }
        // Removes the top two item from the stack ( n1 n2  -- )
        _ = self.dictionary.define(word: "2DROP") {
            _ = try self.pstack.pop()
            _ = try self.pstack.pop()
        }
        // Duplicates the top two item on the stack ( n1 n2 -- n1 n2 n1 n2 )
        _ = self.dictionary.define(word: "2DUP") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1)
            try self.pstack.push(v2)
            try self.pstack.push(v1)
            try self.pstack.push(v2)
        }
        // Exchanges the top two pairs of items on the stack ( n1 n2 n3 n4 -- n3 n4 n1 n2 )
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
        // Duplicates the top item on the stack if it is non-zero ( n -- | n -- n n )
        _ = self.dictionary.define(word: "?DUP") {
            let v = try self.pstack.pop()
            try self.pstack.push(v)
            if v != 0 {
                try self.pstack.push(v)
            }
        }
        // Increments the top item on the stack by 1 ( n -- n+1 )
        _ = self.dictionary.define(word: "1+") {
            try self.pstack.push(try self.add(1, to: try self.pstack.pop()))
        }
        // Decrements the top item on the stack by 1 ( n -- n-1 )
        _ = self.dictionary.define(word: "1-") {
            try self.pstack.push(try self.substract(1, from: try self.pstack.pop()))
        }
        // Increments the top item on the stack by the length of one CELL ( n -- n+c )
        _ = self.dictionary.define(word: "CELL+") {
            try self.pstack.push(try self.add(Memory.Size.cell, to: try self.pstack.pop()))
        }
        // Decrements the top item on the stack by the length of one CELL ( n -- n-c )
        _ = self.dictionary.define(word: "CELL-") {
            try self.pstack.push(try self.substract(Memory.Size.cell, from: try self.pstack.pop()))
        }
        // Increments the top item on the stack by the length of one CHAR ( n -- n+b )
        _ = self.dictionary.define(word: "CHAR+") {
            try self.pstack.push(try self.add(Memory.Size.char, to: try self.pstack.pop()))
        }
        // Decrements the top item on the stack by the length of one CHAR ( n -- n-c )
        _ = self.dictionary.define(word: "CHAR-") {
            try self.pstack.push(try self.substract(Memory.Size.char, from: try self.pstack.pop()))
        }
        // Adds the top two elements of the stack and pushes the result ( n1 n2 -- n1+n2 )
        _ = self.dictionary.define(word: "+") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(try self.add(v1, to: v2))
        }
        // Substracts the second element of the stack from the top element and pushes the result ( n1 n2 -- n1-n2 )
        _ = self.dictionary.define(word: "-") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(try self.substract(v2, from: v1))
        }
        // Multiplies the top two elements of the stack and pushes the result ( n1 n2 -- n1*n2 )
        _ = self.dictionary.define(word: "*") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(try self.multiply(v1, by: v2))
        }
        _ = self.dictionary.define(word: "LSHIFT") { // (
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 << v2)
        }
        _ = self.dictionary.define(word: "RSHIFT") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(v1 >> v2)
        }
        _ = self.dictionary.define(word: "/") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(try self.divide(v1, by: v2))
        }
        _ = self.dictionary.define(word: "MOD") {
            let v2 = try self.pstack.pop()
            let v1 = try self.pstack.pop()
            try self.pstack.push(try self.modulo(v1, by: v2))
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
            self.system.print(String(format: "%c", character), error: false)
        }
        _ = self.dictionary.define(word: "TYPE") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            let text = self.memory[Text(address: address, length: length)]
            self.system.print(String(ascii: text), error: false)
        }
        _ = self.dictionary.define(word: "KEY") {
            try self.pstack.push(Cell(self.key()))
        }
        let word = self.dictionary.define(word: "WORD") {
            let bytes = self.word()
            let text = Text(address: Address.buffer, length: Cell(bytes.count))
            self.memory[text] = bytes
            try self.pstack.push(text.address)
            try self.pstack.push(Cell(text.length))
        }
        _ = self.dictionary.define(word: "NUMBER") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            let text = self.memory[Text(address: address, length: length)]
            let (value, unconverted) = try self.number(text, base: self.base)
            try self.pstack.push(value)
            try self.pstack.push(unconverted)
        }
        _ = self.dictionary.define(word: "CHAR") {
            try self.pstack.push(Cell(self.word().first ?? 0))
        }
        _ = self.dictionary.define(word: "FIND") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            let name = self.memory[Text(address: address, length: length)]
            let word = self.dictionary.find(name)
            if word == 0 {
                throw RuntimeError.unknownWord(name)
            }
            try self.pstack.push(word)
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
        let fetch = self.dictionary.define(word: "@") {
            let address = try self.pstack.pop()
            let cell = self.memory[address] as Cell
            try self.pstack.push(cell)
        }
        _ = self.dictionary.define(word: "PORT!") {
            let port = try self.pstack.pop()
            let value = try self.pstack.pop()
            try self.system.output(port: port, value: value)
        }
        _ = self.dictionary.define(word: "PORT@") {
            let port = try self.pstack.pop()
            let cell = try self.system.input(port: port)
            try self.pstack.push(cell)
        }
        // Stores single byte at address ( n addr -- )
        _ = self.dictionary.define(word: "C!") {
            let address = try self.pstack.pop()
            let value = try self.pstack.pop()
            self.memory[address] = Char(value)
        }
        _ = self.dictionary.define(word: "C@") {
            let address = try self.pstack.pop()
            let cell = self.memory[address] as Char
            try self.pstack.push(Cell(cell))
        }
        _ = self.dictionary.define(word: "+!") {
            let address = try self.pstack.pop()
            let value = try self.pstack.pop()
            self.memory[address] += value
        }
        _ = self.dictionary.define(word: "-!") {
            let address = try self.pstack.pop()
            let value = try self.pstack.pop()
            self.memory[address] -= value
        }
        _ = self.dictionary.define(word: ">R") {
            try self.rstack.push(try self.pstack.pop())
        }
        _ = self.dictionary.define(word: "R>") {
            try self.pstack.push(try self.rstack.pop())
        }
        _ = self.dictionary.define(word: "R@") {
            try self.pstack.push(self.rstack.peek())
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
        _ = self.dictionary.define(word: "DEPTH") {
            try self.pstack.push(self.pstack.depth)
        }
        _ = self.dictionary.define(word: ">BODY") {
            let word = try self.pstack.pop()
            try self.pstack.push(self.dictionary.body(for: word))
        }
        let pad = self.dictionary.define(word: "PAD") {
            try self.pstack.push(self.memory.here + Address.padOffset * Memory.Size.cell)
        }
        _ = self.dictionary.define(word: "CELLS") {
            try self.pstack.push(try self.pstack.pop() * Memory.Size.cell)
        }
        _ = self.dictionary.define(word: "CHARS") {
            try self.pstack.push(try self.pstack.pop() * Memory.Size.char)
        }
        _ = self.dictionary.define(word: "IMMEDIATE", immediate: true) {
            self.dictionary.toggleImmediate(word: self.dictionary.latest)
        }
        let hidden = self.dictionary.define(word: "HIDDEN") {
            self.dictionary.toggleHidden(word: try self.pstack.pop())
        }
        let dirty = self.dictionary.define(word: "DIRTY") {
            self.dictionary.toggleDirty(word: try self.pstack.pop())
        }
        let create = self.dictionary.define(word: "CREATE") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            let name = self.memory[Text(address: address, length: length)]
            _ = self.dictionary.create(word: name, immediate: false)
        }
        let branch = self.dictionary.define(word: "BRANCH") {
            self.currentIp += self.memory[self.currentIp + Memory.Size.cell]
        }
        _ = self.dictionary.define(word: "0BRANCH") {
            let offset: Cell = self.memory[self.currentIp + Memory.Size.cell]
            if  try self.pstack.pop() == 0 {
                self.currentIp += offset
            } else {
                self.currentIp += Memory.Size.cell
            }
        }
        // Compares two strings ( c-addr1 u1 c-addr2 u2 -- n )
        _ = self.dictionary.define(word: "COMPARE") {
            let rhsLength = try self.pstack.pop()
            let rhsAddress = try self.pstack.pop()
            let lhsLength = try self.pstack.pop()
            let lhsAddress = try self.pstack.pop()
            let rhs = String(ascii: self.memory[Text(address: rhsAddress, length: rhsLength)])
            let lhs = String(ascii: self.memory[Text(address: lhsAddress, length: lhsLength)])
            try self.pstack.push(Cell(rhs.compare(lhs).rawValue))
        }
        _ = self.dictionary.define(word: "'") {
            self.currentIp += Memory.Size.cell
            let word: Cell = self.memory[self.currentIp]
            try self.pstack.push(word)
        }
        _ = self.dictionary.define(word: "SEE") {
            let name = self.word()
            let word = self.dictionary.find(name)
            if word == 0 {
                throw RuntimeError.unknownWord(name)
            }
            self.system.print(self.dictionary.see(word: word, base: self.base) + "\n", error: false)
        }
        _ = self.dictionary.define(word: "FORGET") {
            let name = self.word()
            let word = self.dictionary.find(name)
            if word == 0 {
                throw RuntimeError.unknownWord(name)
            }
            self.dictionary.forget(word: word)
        }
        _ = self.dictionary.define(word: "MARKER") {
            let name = self.word()
            _ = self.dictionary.define(word: String(ascii: name)) {
                let word = self.dictionary.find(name)
                if word == 0 {
                    throw RuntimeError.unknownWord(name)
                }
                self.dictionary.forget(word: word)
            }
        }
        _ = self.dictionary.define(word: "WORDS") {
            self.system.print(self.dictionary.words().joined(separator: " ") + "\n", error: false)
        }
        _ = self.dictionary.define(word: "ID.") {
            self.system.print(String(ascii: self.dictionary.id(of: try self.pstack.pop())) + "\n", error: false)
        }
        _ = self.dictionary.define(word: "UNUSED") {
            try self.pstack.push(self.memory.unused)
        }
        // Dumps bytes at an address to stoud in hexdump format ( addr len -- )
        _ = self.dictionary.define(word: "DUMP") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            self.system.print(self.memory.dump(address: address, length: length) + "\n", error: false)
        }
        let comma = self.dictionary.define(word: ",") {
            self.memory.append(cell: try self.pstack.pop())
        }
        _ = self.dictionary.define(word: ":", words: [
            enter,
            word, create,
            lit, enter, comma,
            latest, fetch, hidden,
            latest, fetch, dirty,
            tocompile,
            exit
        ])
        _ = self.dictionary.define(word: ";", immediate: true, words: [
            enter,
            lit, exit, comma,
            lit, Dictionary.marker, comma,
            latest, fetch, hidden,
            latest, fetch, dirty,
            toimmediate,
            exit
        ])
        // Executes the address currently on the pstack ( a -- )
        _ = self.dictionary.define(word: "EXECUTE") {
            // next will be on pstack, then back to the original nextIp
            self.memory[Address.xt0] = try self.pstack.pop()
            self.memory[Address.xt1] = self.currentIp + Memory.Size.cell
            self.currentIp = Address.xt0 - Memory.Size.cell
        }
        // Prints an unsigned number padded to a given width ( n width -- )
        _ = self.dictionary.define(word: "U.R") {
            let width = try self.pstack.pop()
            let number = try self.pstack.pop()
            self.system.print(String(UCell(bitPattern: number), radix: Int(self.base)).uppercased().padLeft(toLength: Int(width), withPad: " "), error: false)
        }
        // Prints a number padded to a given width ( n width -- )
        _ = self.dictionary.define(word: ".R") {
            let width = try self.pstack.pop()
            let number = try self.pstack.pop()
            self.system.print(String(number, radix: Int(self.base)).uppercased().padLeft(toLength: Int(width), withPad: " "), error: false)
        }        
        // Interprets the next word on stdin ( -- )
        let interpret = self.dictionary.define(word: "INTERPRET") {
            let name = self.word()
            if name.count == 0 {
                return
            }

            let word = self.dictionary.find(name)
            if word != 0 { // it's in the dictionary
                let cfa = self.dictionary.body(for: word)
                if self.state == State.immediate || self.dictionary.isImmediate(word: word) {
                    self.memory[Address.ip0] = cfa
                    self.memory[Address.ip1] = self.currentIp
                    self.currentIp = Address.ip0 - Memory.Size.cell
                } else {
                    self.memory.append(cell: cfa)
                }
                return
            }

            let (result, unconverted) = try self.number(name, base: self.base)
            if unconverted == 0 { // it's a number
                if self.state == State.immediate {
                    try self.pstack.push(result)
                } else {
                    self.memory.append(cell: lit)
                    self.memory.append(cell: result)
                }
                return
            }

            throw RuntimeError.parseError(name)
        }

        self.wordQuit = self.dictionary.define(word: "QUIT", words: [
            rz, rspstore, interpret, branch, Memory.Size.cell * -2
        ])
        self.currentIp = wordQuit
    }

    private func add (_ lhs: Cell, to rhs: Cell) throws -> Cell {
        let (result, didOverflow) = lhs.addingReportingOverflow(rhs)
        if didOverflow {
            throw RuntimeError.numberOutOfRange("\(lhs) \(rhs) +")
        }
        return result
    }

    private func substract (_ rhs: Cell, from lhs: Cell) throws -> Cell {
        let (result, didOverflow) = lhs.subtractingReportingOverflow(rhs)
        if didOverflow {
            throw RuntimeError.numberOutOfRange("\(lhs) \(rhs) -")
        }
        return result
    }

    private func multiply (_ lhs: Cell, by rhs: Cell) throws -> Cell {
        let (result, didOverflow) = lhs.multipliedReportingOverflow(by: rhs)
        if didOverflow {
            throw RuntimeError.numberOutOfRange("\(lhs) \(rhs) *")
        }
        return result
    }

    private func divide (_ rhs: Cell, by lhs: Cell) throws -> Cell {
        let (result, didOverflow) = rhs.dividedReportingOverflow(by: lhs)
        if didOverflow {
            throw RuntimeError.numberOutOfRange("\(rhs) \(lhs) /")
        }
        return result
    }

    private func modulo (_ rhs: Cell, by lhs: Cell) throws -> Cell {
        let (result, didOverflow) = rhs.remainderReportingOverflow(dividingBy: lhs)
        if didOverflow {
            throw RuntimeError.numberOutOfRange("\(rhs) \(lhs) MOD")
        }
        return result
    }

    private func key () -> Char {
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

    private func word () -> [Char] {
        var buffer: [Char] = []
        var character: Char = 0

        // skip spaces, tabs and comments
        while true {
            character = self.key()
            while character == Character.space ||
                character == Character.tab {
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

        // read word until space, tab or newline
        while character != Character.space &&
            character != Character.tab &&
            character != Character.newline {
                buffer.append(character)
                character = self.key()
        }

        return Array(buffer[0..<min(Int(Address.bufferSize), buffer.count)])
    }

    private func number (_ bytes: [Char], base: Cell) throws -> (Cell, Cell) {
        if bytes.count == 0 {
            return (0, 0)
        }

        var sign: Cell = 1
        var rest: [Char] = bytes
        if bytes.first == Character.dash {
            sign = -1
            rest = Array(bytes.dropFirst())
        }

        var lastValue: Cell = 0
        for index in stride(from: rest.count - 1, through: 0, by: -1) {
            let string = String(ascii: Array(rest.dropLast(index)))
            if let value = Int(string, radix: Int(base)) {
                if value < Cell.min || value > Cell.max {
                    throw RuntimeError.numberOutOfRange(String(ascii: bytes))
                }
                lastValue = Cell(value)
            } else {
                return (lastValue * sign, Cell(index + 1))
            }
        }

        return (lastValue * sign, 0)
    }

    private func next () {
        self.currentIp += Memory.Size.cell
        self.previousIp = self.currentIp
    }

    private func reset () {
        self.buffer = nil
        self.wantsAbort = false
        self.currentIp = self.wordQuit
        self.pstack.clear()
        self.rstack.clear()
        self.state = State.immediate
        if self.dictionary.isDirty(word: self.dictionary.latest) {
            self.dictionary.forget(word: self.dictionary.latest)
        }
    }

    func run() {
        while true {
            do {
                if self.wantsAbort {
                    throw RuntimeError.abort
                }
                if self.trace > 0 {
                    self.system.print(self.description.styled(style: .dim) + "\n", error: true)
                }

                let word: Cell = self.memory[self.currentIp]
                if let code = self.dictionary.code(of: word) {
                    try code()
                    self.next()
                } else {
                    self.currentIp = word
                }
            } catch {
                self.system.print("\n\(error)\n".styled(style: .bold), error: false)
                self.reset()
            }
        }
    }

    func abort() {
        self.wantsAbort = true
    }
}

extension Machine: CustomStringConvertible {
    var description: String {
        var address = self.currentIp
        let name = self.dictionary.see(at: &address, base: self.base).padding(toLength: 20, withPad: " ", startingAt: 0)
        let ip = "\(self.currentIp)".padding(toLength: 7, withPad: " ", startingAt: 0)
        let pst = self.pstack.dump(base: self.base).padding(toLength: 20, withPad: " ", startingAt: 0)
        let rst = self.rstack.dump(base: self.base).padding(toLength: 20, withPad: " ", startingAt: 0)
        return "IP: \(ip) | PST: \(pst) | RST: \(rst) | \(name)"
    }
}
