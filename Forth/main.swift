//
//  main.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation
import Darwin

var lines: [String] = []

do {
    lines = try String(contentsOf: URL(fileURLWithPath: "./bootstrap.f"))
        .components(separatedBy: .newlines)
        .filter { !$0.isEmpty }
} catch {
    print()
    print("FATAL ERROR: \(error)")
    exit(0)
}

let machine = Machine(system: System(lines: lines))

signal(SIGINT) { _ in
    print()
    machine.interrupt()
}

machine.run()

