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
    case invalidAddress(_: Cell)
}
