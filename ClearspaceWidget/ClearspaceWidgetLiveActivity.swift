//
//  ClearspaceWidgetLiveActivity.swift
//  ClearspaceWidget
//
//  Created by Anshuman Nitnaware on 27/09/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ClearspaceWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ClearspaceWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClearspaceWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ClearspaceWidgetAttributes {
    fileprivate static var preview: ClearspaceWidgetAttributes {
        ClearspaceWidgetAttributes(name: "World")
    }
}

extension ClearspaceWidgetAttributes.ContentState {
    fileprivate static var smiley: ClearspaceWidgetAttributes.ContentState {
        ClearspaceWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ClearspaceWidgetAttributes.ContentState {
         ClearspaceWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ClearspaceWidgetAttributes.preview) {
   ClearspaceWidgetLiveActivity()
} contentStates: {
    ClearspaceWidgetAttributes.ContentState.smiley
    ClearspaceWidgetAttributes.ContentState.starEyes
}
