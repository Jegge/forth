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
    case parseError(_: [Byte])
    case seeUnknownWord(_: [Byte])
    case abort
}

extension RuntimeError: CustomStringConvertible {
    var description: String {
        switch self {
        case .stackDepleted(let name):
            return "Stack error: expected an element on the \(name) stack, but the stack was empty."
        case .stackOverflow(let name):
            return "Stack error: tried to put an element on the \(name) stack, but the stack was full."
        case .parseError(let token):
            return "Parse error: '\(String(ascii: token))' is neither a known word nor a number literal."
        case .seeUnknownWord(let name):
            return "Parse error: Can not decompile an unknown word '\(String(ascii: name))'."
        case .abort:
            return "ABORTED"
        }
    }
}
