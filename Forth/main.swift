//
//  main.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation
import Darwin

// TODO: LEAVE
// TODO: NUMBER -> >NUMBER

var lines: [String] = []

do {
    let url = URL(fileURLWithPath: CommandLine.arguments.first!).deletingLastPathComponent().appendingPathComponent("bootstrap.f")
    lines = try String(contentsOf: url)
        .components(separatedBy: .newlines)
        .filter { !$0.isEmpty }
} catch {
    print()
    print("FATAL ERROR: \(error)")
    exit(0)
}

let system = System(lines: lines)
let memory = Memory(chunk: 4096, max: 1024 * 1024) // 1 mb
let rstack = Stack(memory: memory, address: Address.rstack, size: Address.rstackSize, addressAddress: Address.r0, name: "return")
let pstack = Stack(memory: memory, address: Address.pstack, size: Address.pstackSize, addressAddress: Address.s0, name: "parameter")
let dictionary = Dictionary(memory: memory)
let machine = Machine(system: system, memory: memory, rstack: rstack, pstack: pstack, dictionary: dictionary)

signal(SIGINT) { _ in
    print(" - ABORTING - HIT ENTER")
    machine.abort()
}

machine.run()
