//
//  SpaceSwitcher.swift
//  mouseGesture
//
//  Created by Poulastaa Das on 18/06/26.
//

import CoreGraphics
import Darwin
import Foundation

enum SpaceSwitchMethod: String {
    case systemEvents = "System Events"
    case keyboardShortcut = "Control+Arrow"
}

struct SpaceSwitchResult {
    let method: SpaceSwitchMethod
    let message: String
}

final class SpaceSwitcher {
    private let repeatedShortcutDelay: TimeInterval = 0.18

    func switchSpace(_ direction: GestureDirection, repeatCount: Int = 1) -> SpaceSwitchResult {
        let safeRepeatCount = max(1, min(8, repeatCount))

        if let message = switchUsingSystemEvents(direction, repeatCount: safeRepeatCount) {
            return SpaceSwitchResult(method: .systemEvents, message: message)
        }

        postControlArrowShortcut(direction, repeatCount: safeRepeatCount)
        return SpaceSwitchResult(
            method: .keyboardShortcut,
            message: "Posted \(shortcutSummary(for: direction, repeatCount: safeRepeatCount)) fallback"
        )
    }

    private func switchUsingSystemEvents(_ direction: GestureDirection, repeatCount: Int) -> String? {
        let source = """
        tell application "System Events"
            repeat with pressIndex from 1 to \(repeatCount)
                key code \(direction.arrowKeyCode) using control down
                if pressIndex is less than \(repeatCount) then
                    delay \(repeatedShortcutDelay)
                end if
            end repeat
        end tell
        """

        guard let script = NSAppleScript(source: source) else {
            return nil
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)

        guard error == nil else {
            return nil
        }

        return "Sent \(shortcutSummary(for: direction, repeatCount: repeatCount)) via System Events"
    }

    private func postControlArrowShortcut(_ direction: GestureDirection, repeatCount: Int) {
        for pressIndex in 0..<repeatCount {
            postSingleControlArrowShortcut(direction)

            if pressIndex < repeatCount - 1 {
                usleep(useconds_t(repeatedShortcutDelay * 1_000_000))
            }
        }
    }

    private func postSingleControlArrowShortcut(_ direction: GestureDirection) {
        let source = CGEventSource(stateID: .hidSystemState)

        let arrowDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: direction.arrowKeyCode,
            keyDown: true
        )
        let arrowUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: direction.arrowKeyCode,
            keyDown: false
        )

        arrowDown?.flags = .maskControl
        arrowUp?.flags = .maskControl
        arrowDown?.post(tap: .cghidEventTap)
        usleep(1_000)
        arrowUp?.post(tap: .cghidEventTap)
    }

    private func shortcutSummary(for direction: GestureDirection, repeatCount: Int) -> String {
        guard repeatCount > 1 else {
            return direction.shortcutDisplayName
        }

        return "\(direction.shortcutDisplayName) x\(repeatCount)"
    }
}

private extension GestureDirection {
    var arrowKeyCode: CGKeyCode {
        switch self {
        case .left:
            123
        case .right:
            124
        case .down:
            125
        case .up:
            126
        }
    }

    var shortcutDisplayName: String {
        "Control + \(displayName) Arrow"
    }
}
