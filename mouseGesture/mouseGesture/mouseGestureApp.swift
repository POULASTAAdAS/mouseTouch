//
//  mouseGestureApp.swift
//  mouseGesture
//
//  Created by Poulastaa Das on 18/06/26.
//

import AppKit
import SwiftUI

@main
struct mouseGestureApp: App {
    @StateObject private var controller = MouseGestureController()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MouseGestureMenu()
                .environmentObject(controller)
        } label: {
            Text("MG")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
    }
}

@MainActor
private final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?

    func show(controller: MouseGestureController) {
        if window == nil {
            let hostingController = NSHostingController(
                rootView: ContentView()
                    .environmentObject(controller)
            )
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 580),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Mouse Gesture Settings"
            settingsWindow.contentViewController = hostingController
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.center()
            window = settingsWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct MouseGestureMenu: View {
    @EnvironmentObject private var controller: MouseGestureController

    var body: some View {
        Button {
            SettingsWindowPresenter.shared.show(controller: controller)
        } label: {
            Label("Settings", systemImage: "gearshape")
        }

        Divider()

        Button(controller.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
            if controller.isMonitoring {
                controller.stopMonitoring()
            } else {
                controller.startMonitoring()
            }
        }

        Toggle("Open at login", isOn: launchAtLoginBinding)

        Toggle("Detailed settings", isOn: detailedSettingsBinding)

        Divider()

        Button("Quit Mouse Gesture") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { controller.launchesAtLogin },
            set: { controller.setLaunchesAtLogin($0) }
        )
    }

    private var detailedSettingsBinding: Binding<Bool> {
        Binding(
            get: { controller.settings.showsDetailedSettings },
            set: { controller.setShowsDetailedSettings($0) }
        )
    }
}
