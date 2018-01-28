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
            return "\nError: expected an element on the \(name) stack, but the stack was empty.\n"
        case .stackOverflow(let name):
            return "\nError: tried to put an element on the \(name) stack, but the stack was full.\n"
        case .parseError(let token):
            return "\nError: '\(String(ascii: token))' is neither a known word nor a number literal.\n"
        case .unknownWord(let name):
            return "\nError: '\(String(ascii: name))' is not a known word.\n"
        case .numberOutOfRange(let reason):
            return "\nError: number out of range: '\(reason)'.\n"
        case .abort:
            return ""
        }
    }
}
