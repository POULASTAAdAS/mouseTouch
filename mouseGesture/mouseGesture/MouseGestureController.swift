//
//  MouseGestureController.swift
//  mouseGesture
//
//  Created by Poulastaa Das on 18/06/26.
//

import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Darwin
import Foundation
import OSLog
import ServiceManagement

enum GestureDirection {
    case left
    case right
    case up
    case down

    var displayName: String {
        switch self {
        case .left:
            "Left"
        case .right:
            "Right"
        case .up:
            "Up"
        case .down:
            "Down"
        }
    }
}

final class MouseGestureController: ObservableObject {
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastGesture = "No gesture yet"
    @Published private(set) var liveDrag = CGSize.zero
    @Published private(set) var recentLogEntries: [String] = []
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var settings: MouseGestureSettings
    @Published private(set) var launchesAtLogin = false

    private let eventMask: NSEvent.EventTypeMask = [
        .otherMouseDown,
        .otherMouseDragged,
        .otherMouseUp
    ]

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var trackingStart: CGPoint?
    private var trackingStartDate: Date?
    private var trackingButtonNumber: Int?
    private var lastLoggedDragBucket: Int?
    private let spaceSwitcher = SpaceSwitcher()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.poulastaa.mouseGesture",
        category: "MouseGesture"
    )
    var hasRequiredPermissions: Bool {
        accessibilityTrusted
    }

    init() {
        settings = MouseGestureSettings()
        appendLog(
            "Loaded settings: button \(settings.triggerButtonNumber), threshold \(Int(settings.activationDistance)) px, auto-start \(settings.startsAutomatically), login item \(settings.launchesAtLogin), detailed \(settings.showsDetailedSettings)"
        )
        refreshPermissionStatus()
        refreshLaunchAtLoginStatus()

        if settings.launchesAtLogin, !launchesAtLogin {
            applyLaunchAtLoginPreference(true)
        }

        if settings.startsAutomatically {
            startMonitoring()
        }
    }

    deinit {
        removeEventMonitors()
    }

    func startMonitoring() {
        refreshPermissionStatus()

        guard hasRequiredPermissions else {
            removeEventMonitors()
            isMonitoring = false
            resetTracking()
            updateStatusForCurrentState()
            appendLog("Monitoring not started; missing \(missingPermissionNames)")
            return
        }

        guard !isMonitoring else {
            updateStatusForCurrentState()
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handle(event)
            return event
        }

        isMonitoring = true
        updateStatusForCurrentState()
        appendLog("Started monitoring button \(settings.triggerButtonNumber)")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        removeEventMonitors()
        isMonitoring = false
        resetTracking()
        statusMessage = "Monitoring paused"
        appendLog("Stopped monitoring")
    }

    func requestAccessibilityPermission() {
        refreshPermissionStatus()

        if accessibilityTrusted {
            appendLog("Accessibility permission already granted")
        } else {
            let options = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary

            accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
            appendLog("Requested Accessibility permission; trusted=\(accessibilityTrusted)")
        }

        updateStatusForCurrentState()

        if hasRequiredPermissions, settings.startsAutomatically {
            startMonitoring()
        }
    }

    func refreshAccessibilityStatus() {
        refreshPermissionStatus()
    }

    func refreshPermissionStatus() {
        let previousAccessibilityStatus = accessibilityTrusted
        accessibilityTrusted = AXIsProcessTrusted()
        updateStatusForCurrentState()

        if previousAccessibilityStatus != accessibilityTrusted {
            appendLog("Accessibility trust changed to \(accessibilityTrusted)")
        }
    }

    func openPermissionSettings() {
        let settingsURLs = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        for settingsURL in settingsURLs {
            guard let url = URL(string: settingsURL) else { continue }

            if NSWorkspace.shared.open(url) {
                appendLog("Opened Accessibility settings")
                return
            }
        }

        let settingsAppPaths = [
            "/System/Applications/System Settings.app",
            "/System/Applications/System Preferences.app"
        ]

        for path in settingsAppPaths {
            guard FileManager.default.fileExists(atPath: path),
                  NSWorkspace.shared.open(URL(fileURLWithPath: path)) else {
                continue
            }

            appendLog("Opened system settings app")
            return
        }

        appendLog("Failed to open Accessibility settings")
    }

    func setTriggerButtonNumber(_ value: Int) {
        var updatedSettings = settings
        updatedSettings.triggerButtonNumber = value
        applySettings(updatedSettings)
    }

    func setActivationDistance(_ value: Double) {
        var updatedSettings = settings
        updatedSettings.activationDistance = value
        applySettings(updatedSettings)
    }

    func setStartsAutomatically(_ value: Bool) {
        var updatedSettings = settings
        updatedSettings.startsAutomatically = value
        applySettings(updatedSettings)
    }

    func setLaunchesAtLogin(_ value: Bool) {
        var updatedSettings = settings
        updatedSettings.launchesAtLogin = value

        if updatedSettings == settings {
            applyLaunchAtLoginPreference(value)
            return
        }

        applySettings(updatedSettings)
    }

    func setShowsDetailedSettings(_ value: Bool) {
        var updatedSettings = settings
        updatedSettings.showsDetailedSettings = value
        applySettings(updatedSettings)
    }

    func resetSettings() {
        applySettings(.defaults)
    }

    func clearLogs() {
        recentLogEntries = []
        appendLog("Cleared test log")
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .otherMouseDown:
            beginTrackingIfNeeded(event)
        case .otherMouseDragged:
            updateTrackingIfNeeded()
        case .otherMouseUp:
            endTrackingIfNeeded(event)
        default:
            break
        }
    }

    private func beginTrackingIfNeeded(_ event: NSEvent) {
        guard event.buttonNumber == settings.triggerButtonNumber else {
            appendLog("Ignored mouse down from button \(event.buttonNumber); waiting for button \(settings.triggerButtonNumber)")
            return
        }

        trackingButtonNumber = event.buttonNumber
        trackingStart = NSEvent.mouseLocation
        trackingStartDate = Date()
        liveDrag = .zero
        lastLoggedDragBucket = nil
        statusMessage = "Tracking button \(settings.triggerButtonNumber)"
        appendLog("Mouse down: tracking button \(settings.triggerButtonNumber)")
    }

    private func updateTrackingIfNeeded() {
        guard let trackingStart else { return }

        let currentLocation = NSEvent.mouseLocation
        liveDrag = CGSize(
            width: currentLocation.x - trackingStart.x,
            height: currentLocation.y - trackingStart.y
        )

        let dragBucket = Int(max(abs(liveDrag.width), abs(liveDrag.height)) / 40)
        if dragBucket > 0, dragBucket != lastLoggedDragBucket {
            lastLoggedDragBucket = dragBucket
            appendLog(
                "Dragging: x=\(Int(liveDrag.width.rounded())) px, y=\(Int(liveDrag.height.rounded())) px"
            )
        }
    }

    private func endTrackingIfNeeded(_ event: NSEvent) {
        guard event.buttonNumber == trackingButtonNumber, let trackingStart else {
            appendLog("Mouse up ignored for button \(event.buttonNumber); no active matching drag")
            resetTracking()
            return
        }

        let endLocation = NSEvent.mouseLocation
        let dragDuration = trackingStartDate.map { Date().timeIntervalSince($0) }
        let delta = CGSize(
            width: endLocation.x - trackingStart.x,
            height: endLocation.y - trackingStart.y
        )

        appendLog(
            "Mouse up: completed drag x=\(Int(delta.width.rounded())) px, y=\(Int(delta.height.rounded())) px, duration=\(formatDuration(dragDuration))"
        )
        evaluateCompletedDrag(delta, duration: dragDuration)
        resetTracking()
    }

    private func evaluateCompletedDrag(_ delta: CGSize, duration: TimeInterval?) {
        let horizontalDistance = abs(delta.width)
        let verticalDistance = abs(delta.height)
        let threshold = settings.activationDistance

        let direction: GestureDirection?
        if horizontalDistance >= threshold,
           horizontalDistance >= verticalDistance * settings.dominanceRatio {
            direction = delta.width > 0 ? .right : .left
        } else if verticalDistance >= threshold,
                  verticalDistance >= horizontalDistance * settings.dominanceRatio {
            direction = delta.height > 0 ? .up : .down
        } else {
            appendLog(
                "Gesture ignored: horizontal \(Int(horizontalDistance)) px, vertical \(Int(verticalDistance)) px, threshold \(Int(threshold)) px"
            )
            statusMessage = "Ignored short or diagonal drag"
            return
        }

        guard let direction else { return }
        appendLog("Gesture accepted: \(direction.displayName)")
        switchSpace(direction)
    }

    private func switchSpace(_ direction: GestureDirection) {
        refreshPermissionStatus()

        guard hasRequiredPermissions else {
            lastGesture = "\(direction.displayName) gesture blocked"
            updateStatusForCurrentState()
            appendLog("\(direction.displayName) gesture blocked; missing \(missingPermissionNames)")
            return
        }

        let result = spaceSwitcher.switchSpace(direction)
        lastGesture = "\(direction.displayName) gesture sent via \(result.method.rawValue)"
        statusMessage = result.message
        appendLog(result.message)
        logger.debug("Space switch backend: \(result.method.rawValue, privacy: .public)")
    }

    private func removeEventMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func applySettings(_ newSettings: MouseGestureSettings) {
        var sanitizedSettings = newSettings
        sanitizedSettings.triggerButtonNumber = MouseGestureSettings.clampedButtonNumber(
            sanitizedSettings.triggerButtonNumber
        )
        sanitizedSettings.activationDistance = MouseGestureSettings.clampedActivationDistance(
            sanitizedSettings.activationDistance
        )
        sanitizedSettings.dominanceRatio = max(1.0, min(3.0, sanitizedSettings.dominanceRatio))

        guard sanitizedSettings != settings else { return }

        let oldSettings = settings
        settings = sanitizedSettings
        sanitizedSettings.save()
        appendLog(
            "Settings updated: button \(settings.triggerButtonNumber), threshold \(Int(settings.activationDistance)) px, auto-start \(settings.startsAutomatically), login item \(settings.launchesAtLogin), detailed \(settings.showsDetailedSettings)"
        )

        if oldSettings.triggerButtonNumber != sanitizedSettings.triggerButtonNumber {
            resetTracking()
            updateStatusForCurrentState()
            appendLog("Trigger button changed; active drag reset")
        }

        if oldSettings.launchesAtLogin != sanitizedSettings.launchesAtLogin {
            applyLaunchAtLoginPreference(sanitizedSettings.launchesAtLogin)
        }
    }

    private func refreshLaunchAtLoginStatus() {
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLoginPreference(_ isEnabled: Bool) {
        do {
            if isEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }

            refreshLaunchAtLoginStatus()
            appendLog("Launch at login \(launchesAtLogin ? "enabled" : "disabled")")
        } catch {
            refreshLaunchAtLoginStatus()
            appendLog("Failed to update launch at login: \(error.localizedDescription)")
        }
    }

    private func resetTracking() {
        trackingStart = nil
        trackingStartDate = nil
        trackingButtonNumber = nil
        lastLoggedDragBucket = nil
        liveDrag = .zero
    }

    private func updateStatusForCurrentState() {
        if !hasRequiredPermissions {
            statusMessage = "Grant \(missingPermissionNames) to monitor gestures"
        } else if !isMonitoring {
            statusMessage = "Monitoring paused"
        } else {
            statusMessage = "Monitoring button \(settings.triggerButtonNumber)"
        }
    }

    private var missingPermissionNames: String {
        accessibilityTrusted ? "" : "Accessibility"
    }

    private func appendLog(_ message: String) {
        let timestamp = Self.makeLogTimestamp()
        let entry = "\(timestamp)  \(message)"
        recentLogEntries.insert(entry, at: 0)

        if recentLogEntries.count > 80 {
            recentLogEntries.removeLast(recentLogEntries.count - 80)
        }

        logger.info("\(message, privacy: .public)")
    }

    private func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "unknown" }
        return String(format: "%.2fs", duration)
    }

    private static func makeLogTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
