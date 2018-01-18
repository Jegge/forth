//
//  Stack.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

class Stack {

    private let memory: Memory
    private let size: Cell
    private let addressAddress: Cell

    var address: Cell {
        set {
            self.memory[self.addressAddress] = newValue
        }
        get {
            return self.memory[self.addressAddress]
        }
    }

    var pointer: Cell

    init(memory: Memory, address: Cell, size: Cell, addressAddress: Cell) {
        self.memory = memory
        self.addressAddress = addressAddress
        self.pointer = address
        self.size = size
        self.address = address
    }

    func push(_ cell: Cell) throws {
        if self.pointer <= self.address - self.size {
            throw RuntimeError.stackOverflow
        }
        self.pointer -= Cell(MemoryLayout<Cell>.size)
        self.memory[self.pointer] = cell
    }

    func pop() throws -> Cell {
        if self.pointer >= self.address {
            throw RuntimeError.stackDepleted
        }
        let cell: Cell = self.memory[self.pointer]
        self.pointer += Cell(MemoryLayout<Cell>.size)
        return cell
    }
}
