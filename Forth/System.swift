//
//  System.swift
//  Forth
//
//  Created by Sebastian Boettcher on 16.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

private var standardError = FileHandle.standardError

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

protocol SystemProvided {
    func print(_ string: String, error: Bool)
    func exit(_ value: Cell) -> Never
    func readLine () -> String?
    func input (port: Cell) throws -> Cell
    func output (port: Cell, value: Cell) throws
}

class System: SystemProvided {

    private var lines: [String] = []

    init (lines: [String] = []) {
        self.lines = lines
    }

    func print(_ string: String, error: Bool) {
        if error {
            Swift.print(string, terminator: "", to: &standardError)
        } else {
            Swift.print(string, terminator: "")
        }
    }
    // the warning "Will never be executed" in the followling line is due to a compiler bug involving
    // protocols with return type Never
    func exit(_ value: Cell) -> Never {
        Darwin.exit(Int32(value))
    }
    func readLine () -> String? {
        if self.lines.count > 0 {
            return self.lines.removeFirst() + "\n"
        }
        return Swift.readLine(strippingNewline: false)
    }

    func input (port: Cell) throws  -> Cell {
        // ...
        return 23
    }

    func output (port: Cell, value: Cell) throws {
        // ...
    }
}
