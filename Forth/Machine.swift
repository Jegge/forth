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

    init (system: SystemProvided, chunk: Cell = 4096) {
        self.system = system
        self.memory = Memory(chunk: chunk)
        self.rstack = Stack(memory: self.memory, address: Address.rstack, size: 256, addressAddress: Address.r0)
        self.pstack = Stack(memory: self.memory, address: Address.pstack, size: 512, addressAddress: Address.s0)
        self.memory.here = Address.dictionary
        self.dictionary = Dictionary(memory: self.memory)

        _ = self.dictionary.define(variable: "HERE", address: Address.here, stack: self.pstack)
        _ = self.dictionary.define(variable: "STATE", value: State.immediate, address: Address.state, stack: self.pstack)
        let latest = self.dictionary.define(variable: "LATEST", address: Address.latest, stack: self.pstack)
        _ = self.dictionary.define(variable: "BASE", value: 10, address: Address.base, stack: self.pstack)
        _ = self.dictionary.define(variable: "TRACE", value: 0, address: Address.trace, stack: self.pstack)
        _ = self.dictionary.define(variable: "S0", address: Address.s0, stack: self.pstack)

        _ = self.dictionary.define(constant: "VERSION", value: Constants.version, stack: self.pstack)
        let rz = self.dictionary.define(constant: "R0", value: Address.rstack, stack: self.pstack)
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
        _ = self.dictionary.define(word: ">DFA", words: [ docol, tcfa, inccell, exit ])

        _ = self.dictionary.define(word: "IMMEDIATE", immediate: true) {
            self.memory[self.dictionary.latest + Memory.Size.cell] ^= Flags.immediate
        }
        let hidden = self.dictionary.define(word: "HIDDEN") {
            self.memory[try self.pstack.pop() + Memory.Size.cell] ^= Flags.hidden
        }
        _ = self.dictionary.define(word: "HIDE", words: [ docol, word, find, hidden, exit ])
        
        let create = self.dictionary.define(word: "CREATE") {
            let length = try self.pstack.pop()
            let address = try self.pstack.pop()
            let name = self.memory[Text(address: address, length: Byte(length))]
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
        let comma = self.dictionary.define(word: ",") {
            self.memory.append(cell: try self.pstack.pop())
        }
        _ = self.dictionary.define(word: "NUMBER") {
            // TODO
        }
        _ = self.dictionary.define(word: ":", words: [ docol, word, create, lit, docol, comma, latest, hidden, tocompile, exit ])
        _ = self.dictionary.define(word: ";", immediate: true, words: [ docol, lit, exit, comma, latest, hidden, toimmediate, exit ])

        let interpret = self.dictionary.define(word: "INTERPRET") {

            self.memory[self.execAddress] = self.ignore

            let text = self.word()
            let name = self.memory[text]
            let link = self.dictionary.find(byName: name)

            if link != 0 { // it's in the dictionary
                let cfa = self.dictionary.tcfa(link: link)
                if self.state == State.immediate || (self.dictionary.flags(of: link) & Flags.immediate == Flags.immediate) {
                    self.memory[self.execAddress] = cfa
                } else {
                    self.memory.append(cell: cfa)
                }
                return
            }

            let (result, unconverted) = self.number(text, base: self.base)
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

        _ = self.dictionary.define(word: ".") {
            print(try self.pstack.pop())
        }

        self.ignore = self.dictionary.define(word: "IGNORE") {
            // intentionally left blank
        }

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

        let bytes = Array(buffer[0..<min(Constants.wordlen, buffer.count)])
        let text = Text(address: Address.buffer, length: Byte(bytes.count))
        self.memory[text] = bytes

        return text
    }

    private func number (_ text: Text, base: Cell) -> (Cell, Cell) {

        if text.length == 0 {
            return (0, 0)
        }

        var lastValue: Cell = 0
        for index in 1...text.length {
            let string = String(ascii: self.memory[Text(address: text.address, length: index)])
            if let value = Int(string, radix: Int(base)) {
                lastValue = Cell(value)
            } else {
                return (lastValue, Cell(text.length - index))
            }
        }

        return (lastValue, 0)
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
                self.buffer = nil
                self.nextIp = self.quit
            }
        }
    }

    func interrupt() {
        self.buffer = nil
        self.nextIp = self.quit
    }
}

extension Machine: CustomStringConvertible {
    var description: String {
        let word: Cell = self.dictionary.link(for: self.memory[self.nextIp])
        var name = String(ascii: self.dictionary.name(of: word))
        if name == "LIT" || name == "BRANCH" || name == "0BRANCH" {
            let data: Cell = self.memory[self.nextIp + Memory.Size.cell]
            name += " \(data)"
        }
        name = name.padding(toLength: 16, withPad: " ", startingAt: 0)
        let ip = "\(self.nextIp)".padding(toLength: 7, withPad: " ", startingAt: 0)
        let pst = "\(self.pstack)".padding(toLength: 20, withPad: " ", startingAt: 0)
        let rst = "\(self.rstack)".padding(toLength: 20, withPad: " ", startingAt: 0)
        //let latest = self.dictionary.description(ofWord: self.dictionary.latest)
        return "\(name) | IP: \(ip) | PST: \(pst) | RST: \(rst)" //" | LATEST: \(latest)"
    }
}

