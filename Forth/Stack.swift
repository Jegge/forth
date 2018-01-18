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
        self.pointer -= Memory.Size.cell
        self.memory[self.pointer] = cell
    }

    func pop() throws -> Cell {
        if self.pointer >= self.address {
            throw RuntimeError.stackDepleted
        }
        let cell: Cell = self.memory[self.pointer]
        self.pointer += Memory.Size.cell
        return cell
    }
}

extension Stack: CustomStringConvertible {
    var description: String {
        var result = "["
        for index in stride(from: Int(self.address), to: Int(self.pointer - Memory.Size.cell), by: Int(-Memory.Size.cell)) {
            let cell: Cell = self.memory[Cell(index)]
            result += "\(cell), "
        }
        if self.address != self.pointer {
            let cell: Cell = self.memory[self.pointer]
            result += "\(cell)"
        }
        return result + "]"
    }
}
