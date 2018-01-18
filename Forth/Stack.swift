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

    let top: Cell
    var ptr: Cell

    init(memory: Memory, top: Cell, size: Cell) {
        self.memory = memory
        self.top = top
        self.ptr = top
        self.size = size
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

    func reset () {
        self.ptr = self.top
    }
}
