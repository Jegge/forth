//
//  Machine.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation



class Machine {

    private let stackSize: Address = 1024

    private var memory: Memory
    private var pstack: Stack
    private var rstack: Stack
    
    private var oldIp: Address = 0  // current / previous instruction pointer
    private var nxtIp: Address = 0  // next instruction pointer

    private var latest: Address = 0

    init () {
        self.memory = Memory()
        self.pstack = Stack(memory: self.memory, top: Address.max, size: self.stackSize)
        self.rstack = Stack(memory: self.memory, top: Address.max - self.stackSize, size: self.stackSize)

        self.memory.insert(byte: 1)
        self.memory.insert(byte: 0)

        let docol = self.memory.defineWord(name: ":", link: 0) {
            try self.rstack.push(address: self.oldIp)
            self.next()
        }
        let exit = self.memory.defineWord(name: ";", link: docol) {
            self.nxtIp = try self.rstack.popAddress()
            self.next()
        }
        let lit = self.memory.defineWord(name: "LIT", link: exit) {
            self.next()
            try self.pstack.push(cell: self.memory.get(cellAt: self.nxtIp))
            self.next()
        }
        let inc2 = self.memory.defineWord(name: "2+", link: lit) {
            try self.pstack.push(cell: try self.pstack.popCell() + 2)
            self.next()
        }
        let cfa = self.memory.defineWord(name: ">CFA", link: inc2) {
            try self.pstack.push(address: self.memory.cfa(try self.pstack.popAddress()))
            self.next()
        }

        let dot = self.memory.defineWord(name: ".", link: cfa) {
            print(try self.pstack.popCell())
            self.next()
        }
        let mult = self.memory.defineWord(name: "*", link: dot) {
            try self.pstack.push(cell: try self.pstack.popCell() * self.pstack.popCell())
            self.next()
        }
        let double = self.memory.defineWord(name: "DOUBLE", link: mult, words: [
            self.memory.cfa(docol),
            self.memory.cfa(lit), 2,
            self.memory.cfa(mult),
            self.memory.cfa(exit)
        ])
        let quad = self.memory.defineWord(name: "QUAD", link: double, words: [
            self.memory.cfa(docol),
            self.memory.cfa(double),
            self.memory.cfa(double),
            self.memory.cfa(exit)
        ])
        let test = self.memory.defineWord(name: "TEST", link: quad, words: [
            self.memory.cfa(lit), 3,
            self.memory.cfa(quad),
            self.memory.cfa(dot),
            self.memory.cfa(exit)
        ])

        self.latest = test
    }

    private func next () {
        self.nxtIp += Address(MemoryLayout<Address>.size)
        self.oldIp = self.nxtIp
    }

    func run () throws {

        self.memory.dump(cap: 128)
        print()
        self.nxtIp = self.memory.cfa(self.latest) // Start with "TEST"
//        print("START \(self.nxtIp)")

        while true {
            let word = self.memory.get(addressAt: self.nxtIp)
            if try !self.memory.runNative(at: word) {
//                print("Word \(word) -> word")
                self.nxtIp = word
//            } else {
//                print("Word \(word) -> code")
            }
        }
    }
}
