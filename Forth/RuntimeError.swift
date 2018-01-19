//
//  RuntimeError.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

enum RuntimeError: Error {
    case stackDepleted
    case stackOverflow
    case expectedWord
    case parseError(_:[Byte])
    case seeUnknownWord(_:[Byte])
}

extension RuntimeError: CustomStringConvertible {
    var description: String {
        switch self {
        case .stackDepleted:
            return "Expected an element on the stack, but the stack was empty."
        case .stackOverflow:
            return "Tried to put an element on the stack, but the stack was full."
        case .expectedWord:
            return "Expected to read a word."
        case .parseError(let token):
            return "Parse error: '\(String(ascii: token))' is neither a known word nor a number literal."
        case .seeUnknownWord(let name):
            return "Can not decompile an unknown word '\(String(ascii: name))'."
        }
    }
}
