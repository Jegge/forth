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
    private let topStorage: Cell

    var top: Cell {
        set {
            self.memory[self.topStorage] = newValue
        }
        get {
            return self.memory[self.topStorage]
        }
    }

    var ptr: Cell

    init(memory: Memory, top: Cell, size: Cell, topStorage: Cell) {
        self.memory = memory
        self.topStorage = topStorage
        self.ptr = top
        self.size = size
        self.top = top
    }

    func push(_ cell: Cell) throws {
        if self.ptr <= self.top - self.size {
            throw RuntimeError.stackOverflow
        }
        self.ptr -= Cell(MemoryLayout<Cell>.size)
        self.memory[self.ptr] = cell
    }

    func pop() throws -> Cell {
        if self.ptr >= self.top {
            throw RuntimeError.stackDepleted
        }
        let cell: Cell = self.memory[self.ptr]
        self.ptr += Cell(MemoryLayout<Cell>.size)
        return cell
    }
}
