//
//  Stack.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

class Stack {

    let memory: Memory
    let top: Address
    let size: Address
    private (set) var ptr: Address

    init(memory: Memory, top: Address, size: Address) {
        self.memory = memory
        self.top = top
        self.ptr = top
        self.size = size
    }

    func push(address: Address) throws {
        if self.ptr <= self.top - self.size {
            throw RuntimeError.stackOverflow
        }
        self.ptr -= Address(MemoryLayout<Address>.size)
        self.memory.set(address: address, at: self.ptr)
    }
    func push(cell: Cell) throws {
        if self.ptr <= self.top - self.size {
            throw RuntimeError.stackOverflow
        }
        self.ptr -= Address(MemoryLayout<Cell>.size)
        self.memory.set(cell: cell, at: self.ptr)

    }
    func popAddress () throws -> Address {
        if self.ptr >= self.top {
            throw RuntimeError.stackDepleted
        }
        let address = self.memory.get(addressAt: self.ptr)
        self.ptr += Address(MemoryLayout<Address>.size)
        return address
    }
    func popCell () throws -> Cell {
        if self.ptr >= self.top {
            throw RuntimeError.stackDepleted
        }
        let cell = self.memory.get(cellAt: self.ptr)
        self.ptr += Address(MemoryLayout<Cell>.size)
        return cell
    }
    func reset () {
        self.ptr = self.top
    }
}
