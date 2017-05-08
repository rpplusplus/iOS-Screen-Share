//
//  HouraiUSBProtocol.swift
//  Hourai
//
//  Created by txx on 22/03/2017.
//  Copyright © 2017 liwushuo. All rights reserved.
//

import Foundation

enum USBProtocol: UInt32 {
    case PING = 102
    case PONG = 103
    case DATA = 104
}
