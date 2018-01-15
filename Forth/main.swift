//
//  main.swift
//  Forth
//
//  Created by Sebastian Boettcher on 15.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

do {
    let vm = Machine()
    try vm.run()
} catch {
    print()
    print("ERROR: \(error)")
}
