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
        }
        let exit = self.memory.defineWord(name: ";", link: docol) {
            self.nxtIp = try self.rstack.popAddress()
        }
        let lit = self.memory.defineWord(name: "LIT", link: exit) {
            self.next()
            try self.pstack.push(cell: self.memory.get(cellAt: self.nxtIp))
        }
        let drop = self.memory.defineWord(name: "DROP", link: lit) {
            _ = try self.pstack.popCell()
        }
        let swap = self.memory.defineWord(name: "SWAP", link: drop) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v2)
            try self.pstack.push(cell: v1)
        }
        let dup = self.memory.defineWord(name: "DUP", link: swap) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: v)
            try self.pstack.push(cell: v)
        }
        let over = self.memory.defineWord(name: "OVER", link: dup) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1)
            try self.pstack.push(cell: v2)
            try self.pstack.push(cell: v1)
        }
        let rot = self.memory.defineWord(name: "ROT", link: over) {
            let v3 = try self.pstack.popCell()
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v2)
            try self.pstack.push(cell: v3)
            try self.pstack.push(cell: v1)
        }
        let nrot = self.memory.defineWord(name: "-ROT", link: rot) {
            let v3 = try self.pstack.popCell()
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v3)
            try self.pstack.push(cell: v1)
            try self.pstack.push(cell: v2)
        }
        let twodrop = self.memory.defineWord(name: "2DROP", link: nrot) {
            _ = try self.pstack.popCell()
            _ = try self.pstack.popCell()
        }
        let twodup = self.memory.defineWord(name: "2DUP", link: twodrop) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1)
            try self.pstack.push(cell: v2)
            try self.pstack.push(cell: v1)
            try self.pstack.push(cell: v2)
        }
        let twoswap = self.memory.defineWord(name: "2SWAP", link: twodup) {
            let v4 = try self.pstack.popCell()
            let v3 = try self.pstack.popCell()
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v3)
            try self.pstack.push(cell: v4)
            try self.pstack.push(cell: v1)
            try self.pstack.push(cell: v2)
        }
        let ifdup = self.memory.defineWord(name: "?DUP", link: twoswap) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: v)
            if v != 0 {
                try self.pstack.push(cell: v)
            }
        }
        let inc1 = self.memory.defineWord(name: "1+", link: ifdup) {
            try self.pstack.push(cell: try self.pstack.popCell() + 1)
        }
        let dec1 = self.memory.defineWord(name: "1-", link: inc1) {
            try self.pstack.push(cell: try self.pstack.popCell() - 1)
        }
        let inc2 = self.memory.defineWord(name: "2+", link: dec1) {
            try self.pstack.push(cell: try self.pstack.popCell() + 2)
        }
        let dec2 = self.memory.defineWord(name: "2-", link: inc2) {
            try self.pstack.push(cell: try self.pstack.popCell() - 2)
        }
        let add = self.memory.defineWord(name: "+", link: dec2) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 + v2)
        }
        let sub = self.memory.defineWord(name: "-", link: add) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 - v2)
        }
        let mult = self.memory.defineWord(name: "*", link: sub) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 * v2)
        }
        let divmod = self.memory.defineWord(name: "/MOD", link: mult) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 / v2)
            try self.pstack.push(cell: v1 % v2)
        }
        let equ = self.memory.defineWord(name: "=", link: divmod) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 == v2 ? 1 : 0)
        }
        let nequ = self.memory.defineWord(name: "<>", link: equ) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 != v2 ? 1 : 0)
        }
        let lt = self.memory.defineWord(name: "<", link: nequ) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 < v2 ? 1 : 0)
        }
        let gt = self.memory.defineWord(name: ">", link: lt) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 > v2 ? 1 : 0)
        }
        let lte = self.memory.defineWord(name: "<=", link: gt) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 <= v2 ? 1 : 0)
        }
        let gte = self.memory.defineWord(name: ">=", link: lte) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 >= v2 ? 1 : 0)
        }
        let zequ = self.memory.defineWord(name: "0=", link: gte) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: v == 0 ? 1 : 0)
        }
        let znequ = self.memory.defineWord(name: "0<>", link: zequ) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: v != 0 ? 1 : 0)
        }
        let zlt = self.memory.defineWord(name: "0<", link: znequ) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: v < 0 ? 1 : 0)
        }
        let zgt = self.memory.defineWord(name: "0>", link: zlt) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: v > 0 ? 1 : 0)
        }
        let zlte = self.memory.defineWord(name: "0<=", link: zgt) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: v <= 0 ? 1 : 0)
        }
        let zgte = self.memory.defineWord(name: "0>=", link: zlte) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: v >= 0 ? 1 : 0)
        }
        let and = self.memory.defineWord(name: "AND", link: zgte) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 & v2)
        }
        let or = self.memory.defineWord(name: "OR", link: and) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 | v2)
        }
        let xor = self.memory.defineWord(name: "XOR", link: or) {
            let v2 = try self.pstack.popCell()
            let v1 = try self.pstack.popCell()
            try self.pstack.push(cell: v1 ^ v2)
        }
        let not = self.memory.defineWord(name: "INVERT", link: xor) {
            let v = try self.pstack.popCell()
            try self.pstack.push(cell: ~v)
        }
        let cfa = self.memory.defineWord(name: ">CFA", link: not) {
            try self.pstack.push(address: self.memory.cfa(try self.pstack.popAddress()))
        }
        let dot = self.memory.defineWord(name: ".", link: cfa) {
            print(try self.pstack.popCell())
        }
        let store = self.memory.defineWord(name: "!", link: dot) {
            let a = try self.pstack.popAddress()
            let v = try self.pstack.popCell()
            self.memory.set(cell: v, at: a)
        }
        let fetch = self.memory.defineWord(name: "@", link: store) {
            try self.pstack.push(cell: self.memory.get(cellAt: try self.pstack.popAddress()))
        }
        let addstore = self.memory.defineWord(name: "+!", link: fetch) {
            let a = try self.pstack.popAddress()
            let v = try self.pstack.popCell()
            self.memory.set(cell: self.memory.get(cellAt: a) + v, at: a)
        }
        let substore = self.memory.defineWord(name: "-!", link: addstore) {
            let a = try self.pstack.popAddress()
            let v = try self.pstack.popCell()
            self.memory.set(cell: self.memory.get(cellAt: a) - v, at: a)
        }
        let storeb = self.memory.defineWord(name: "C!", link: substore) {
            let a = try self.pstack.popAddress()
            let v = try self.pstack.popCell()
            self.memory.set(byte: Byte(v), at: a)
        }
        let fetchb = self.memory.defineWord(name: "C@", link: storeb) {
            try self.pstack.push(cell: Cell(self.memory.get(byteAt: try self.pstack.popAddress())))
        }

//        let latest = self.memory.defineWord(name: "LATEST", link: fetchb) {
//            self.pstack.push()
//            self.next()
//        }




        let double = self.memory.defineWord(name: "DOUBLE", link: fetchb, words: [
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

        self.memory.dump(cap: self.latest + 10)
        print()
        self.nxtIp = self.memory.cfa(self.latest) // Start with "TEST"

        while true {
            let word = self.memory.get(addressAt: self.nxtIp)
            if try self.memory.runNative(at: word) {
                self.next()
            } else {
                self.nxtIp = word
            }
        }
    }
}
