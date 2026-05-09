//
//  Item.swift
//  TimeLog2
//
//  Created by Alberto Barrago on 10/05/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
