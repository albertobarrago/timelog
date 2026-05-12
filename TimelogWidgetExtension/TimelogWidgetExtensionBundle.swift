//
//  TimelogWidgetExtensionBundle.swift
//  TimelogWidgetExtension
//
//  Created by Alberto Barrago on 10/05/2026.
//

import WidgetKit
import SwiftUI

@main
struct TimelogWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        TimelogWidgetExtension()
        TimelogWidgetExtensionLiveActivity()
    }
}
