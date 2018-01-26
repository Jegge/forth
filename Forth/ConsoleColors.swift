//
//  ConsoleColors.swift
//  Forth
//
//  Created by Sebastian Boettcher on 26.01.18.
//  Copyright © 2018 Sebastian Boettcher. All rights reserved.
//

import Foundation

extension String {

    enum Color: UInt8 {
        case black = 30
        case red
        case green
        case yellow
        case blue
        case magenta
        case cyan
        case white
        case `default` = 39
        case lightBlack = 90
        case lightRed
        case lightGreen
        case lightYellow
        case lightBlue
        case lightMagenta
        case lightCyan
        case lightWhite
    }

    enum Style: UInt8 {
        case `default` = 0
        case bold = 1
        case dim = 2
        case italic = 3
        case underline = 4
        case blink = 5
        case swap = 7
    }

    func styled(foreground: Color = .default, background: Color = .default, style: Style = .default) -> String {
        return "\u{001B}[\(foreground.rawValue);\(background.rawValue);\(style.rawValue)m\(self)\u{001B}[0m"
    }
}
