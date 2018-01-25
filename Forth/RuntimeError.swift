//
//  RuntimeError.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

enum RuntimeError: Error {
    case stackDepleted(_: String)
    case stackOverflow(_: String)
    case parseError(_: [Char])
    case unknownWord(_: [Char])
    case numberOutOfRange(_: String)
    case abort
}

extension RuntimeError: CustomStringConvertible {
    var description: String {
        switch self {
        case .stackDepleted(let name):
            return "Error: expected an element on the \(name) stack, but the stack was empty."
        case .stackOverflow(let name):
            return "Error: tried to put an element on the \(name) stack, but the stack was full."
        case .parseError(let token):
            return "Error: '\(String(ascii: token))' is neither a known word nor a number literal."
        case .unknownWord(let name):
            return "Error: '\(String(ascii: name))' is not a known word."
        case .numberOutOfRange(let reason):
            return "Error: number out of range: '\(reason)'"
        case .abort:
            return ""
        }
    }
}
