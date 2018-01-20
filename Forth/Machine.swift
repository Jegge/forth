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

    private var quit: Cell = 0
    private var ignore: Cell = 0
    private var execAddress: Cell = 0

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

        _ = self.dictionary.define(constant: "VERSION", value: Constants.version, stack: self.pstack)
        let rz = self.dictionary.define(constant: "R0", value: Address.rstack, stack: self.pstack)
        _ = self.dictionary.define(constant: "F_IMMED", value: Cell(Flags.immediate), stack: self.pstack)
        _ = self.dictionary.define(constant: "F_DIRTY", value: Cell(Flags.dirty), stack: self.pstack)
        _ = self.dictionary.define(constant: "F_HIDDEN", value: Cell(Flags.hidden), stack: self.pstack)
        _ = self.dictionary.define(constant: "F_LENMASK", value: Cell(Flags.lenmask), stack: self.pstack)
        _ = self.dictionary.define(constant: "MARKER", value: Dictionary.marker, stack: self.pstack)

        let enter = self.dictionary.define(word: "ENTER") {
            try self.rstack.push(self.oldIp)
        }
        _ = self.dictionary.define(constant: "DOCOL", value: enter, stack: self.pstack)
        let exit = self.dictionary.define(word: "EXIT") {
            self.nextIp = try self.rstack.pop()
        }
        let lit = self.dictionary.define(word: "LIT") {
            self.next()
            try self.pstack.push(self.memory[self.nextIp])
        }
        _ = self.dictionary.define(word: "LITSTRING") {
            self.next()
            let length = self.memory[self.nextIp] as Cell
            let address = self.nextIp + Memory.Size.cell
            try self.pstack.push(address)
            try self.pstack.push(length)
            self.nextIp = Memory.align(address: self.nextIp + length)
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
        let inccell = self.dictionary.define(word: "C+") {
            try self.pstack.push(try self.pstack.pop() + Memory.Size.cell)
        }
        _ = self.dictionary.define(word: "C-") {
            try self.pstack.push(try self.pstack.pop() - Memory.Size.cell)
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
        _ = self.dictionary.define(word: "*") {
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
        _ = self.dictionary.define(word: "TELL") {
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
            let (value, unconverted) = self.number(text, base: self.base)
            try self.pstack.push(value)
            try self.pstack.push(unconverted)
        }
        _ = self.dictionary.define(word: "CHAR") {
            try self.pstack.push(Cell(self.word().first ?? 0))
        }
        let find = self.dictionary.define(word: "FIND") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            let name = self.memory[Text(address: address, length: length)]
            let link = self.dictionary.find(name)
//            print(" --- FIND: \(String(ascii: name)) -> \(link)")
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
        let fetch = self.dictionary.define(word: "@") {
            let address = try self.pstack.pop()
            let cell = self.memory[address] as Cell
            try self.pstack.push(cell)
        }
        _ = self.dictionary.define(word: "C!") {
            let address = try self.pstack.pop()
            let value = try self.pstack.pop()
            self.memory[address] = Byte(value)
        }
        _ = self.dictionary.define(word: "C@") {
            let address = try self.pstack.pop()
            let cell = self.memory[address] as Byte
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
            try self.pstack.push(self.dictionary.tcfa(word: address))
        }
        _ = self.dictionary.define(word: "CFA>") {
            let address = try self.pstack.pop()
            try self.pstack.push(self.dictionary.cfat(at: address))
        }
        _ = self.dictionary.define(word: ">DFA", words: [ enter, tcfa, inccell, exit ])

        _ = self.dictionary.define(word: "IMMEDIATE", immediate: true) {
            self.memory[self.dictionary.latest + Memory.Size.cell] ^= Flags.immediate
        }
        let hidden = self.dictionary.define(word: "HIDDEN") {
            self.memory[try self.pstack.pop() + Memory.Size.cell] ^= Flags.hidden
        }
        let dirty = self.dictionary.define(word: "DIRTY") {
            self.memory[try self.pstack.pop() + Memory.Size.cell] ^= Flags.dirty
        }

        _ = self.dictionary.define(word: "HIDE", words: [ enter, word, find, hidden, exit ])
        
        let create = self.dictionary.define(word: "CREATE") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            let name = self.memory[Text(address: address, length: length)]
            _ = self.dictionary.create(word: name, immediate: false)
        }
        let branch = self.dictionary.define(word: "BRANCH") {
            self.nextIp += self.memory[self.nextIp + Memory.Size.cell]
        }
        _ = self.dictionary.define(word: "0BRANCH") {
            let offset: Cell = self.memory[self.nextIp + Memory.Size.cell]
            if  try self.pstack.pop() == 0 {
                self.nextIp += offset
            } else {
                self.nextIp += Memory.Size.cell
            }
        }
        _ = self.dictionary.define(word: "'") {
            self.nextIp += Memory.Size.cell
            let word: Cell = self.memory[self.nextIp]
            try self.pstack.push(word)
        }
        _ = self.dictionary.define(word: "SEE") {
            let name = self.word()
            let word = self.dictionary.find(name)
            if word == 0 {
                throw RuntimeError.seeUnknownWord(name)
            }
            self.system.print(self.dictionary.see(word: word) + "\n", error: false)
        }
        _ = self.dictionary.define(word: "WORDS") {
            self.system.print(self.dictionary.words().joined(separator: " ") + "\n", error: false)
        }
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
        _ = self.dictionary.define(word: "EXECUTE") {
            // next will be on pstack, then back to the original nextIp
            self.memory[Address.xt0] = try self.pstack.pop()
            self.memory[Address.xt1] = self.nextIp + Memory.Size.cell
            self.nextIp = Address.xt0 - Memory.Size.cell
        }

        let interpret = self.dictionary.define(word: "INTERPRET") {

            self.memory[self.execAddress] = self.ignore
            let name = self.word()
            if name.count == 0 {
                return
            }

            let word = self.dictionary.find(name)
            if word != 0 { // it's in the dictionary
                let cfa = self.dictionary.tcfa(word: word)
                if self.state == State.immediate || self.dictionary.isImmediate(word: word) {
                    self.memory[self.execAddress] = cfa
                } else {
                    self.memory.append(cell: cfa)
                }
                return
            }

            let (result, unconverted) = self.number(name, base: self.base)
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

        self.ignore = self.dictionary.define(word: "IGNORE") { /* intentionally left blank */ }
        self.quit = self.dictionary.define(word: "QUIT", words: [ rz, rspstore, interpret, ignore, branch, Memory.Size.cell * -3 ])

        self.execAddress = self.quit + Memory.Size.cell * 3
        self.nextIp = quit
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

    private func word () -> [Byte] {
        var buffer: [Byte] = []
        var character: Byte = 0

        // skip spaces, tabs and comments
        while (true) {
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

        return Array(buffer[0..<min(Constants.wordlen, buffer.count)])
    }

    private func number (_ bytes: [Byte], base: Cell) -> (Cell, Cell) {

        if bytes.count == 0 {
            return (0, 0)
        }

        var sign: Cell = 1
        var rest: [Byte] = bytes
        if bytes.first == Character.dash {
            sign = -1
            rest = Array(bytes.dropFirst())
        }

        var lastValue: Cell = 0
        for index in stride(from: rest.count - 1, through: 0, by: -1) {
            let string = String(ascii: Array(rest.dropLast(index)))
            if let value = Int(string, radix: Int(base)) {
                lastValue = Cell(value)
            } else {
                return (lastValue * sign, Cell(index + 1))
            }
        }

        return (lastValue * sign, 0)
    }

    private func next () {
        self.nextIp += Memory.Size.cell
        self.oldIp = self.nextIp
    }

    func run() {
        while true {
            do {
                if self.trace > 0 {
                    self.system.print(self.description + "\n", error: true)
                }

                let word: Cell = self.memory[self.nextIp]
                if let code = self.dictionary.code(of: word) {
                    try code()
                    self.next()
                } else {
                    self.nextIp = word
                }
            } catch {
                self.system.print("ERROR: \(error)\n", error: false)
                self.interrupt(hard: false)
            }
        }
    }

    func interrupt(hard: Bool) {
        self.buffer = nil
        self.nextIp = self.quit
        self.state = State.immediate
        if hard {
            self.pstack.pointer = self.pstack.address
        }
        if self.dictionary.isDirty(word: self.dictionary.latest) {
            self.dictionary.removeLatest()
        }
    }
}

extension Machine: CustomStringConvertible {
    var description: String {
        let word: Cell = self.dictionary.cfat(at: self.memory[self.nextIp])
        var name = String(ascii: self.dictionary.id(of: word))
        if name == "LIT" || name == "BRANCH" || name == "0BRANCH" {
            name += " \(self.memory[self.nextIp + Memory.Size.cell] as Cell)"
        }
        if name == "LITSTRING" {
            name += " \(self.memory[self.nextIp + Memory.Size.cell] as Cell) ..."
        }
        name = name.padding(toLength: 16, withPad: " ", startingAt: 0)
        let ip = "\(self.nextIp)".padding(toLength: 7, withPad: " ", startingAt: 0)
        let pst = "\(self.pstack)".padding(toLength: 20, withPad: " ", startingAt: 0)
        let rst = "\(self.rstack)".padding(toLength: 20, withPad: " ", startingAt: 0)
        return "\(name) | IP: \(ip) | PST: \(pst) | RST: \(rst) | S: \(self.state == State.immediate ? "I" : "C")"
    }
}

