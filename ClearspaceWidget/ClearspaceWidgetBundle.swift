//
//  ClearspaceWidgetBundle.swift
//  ClearspaceWidget
//
//  Created by Anshuman Nitnaware on 27/09/26.
//

import WidgetKit
import SwiftUI

@main
struct ClearspaceWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClearspaceStorageWidget()
        ClearspaceWidgetControl()
        ClearspaceWidgetLiveActivity()
    }
}
