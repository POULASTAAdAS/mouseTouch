//
//  ContentView.swift
//  mouseGesture
//
//  Created by Poulastaa Das on 18/06/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: MouseGestureController

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            Divider()
            permissionSection
            appSettingsSection

            if controller.settings.showsDetailedSettings {
                Divider()
                gestureSection
                Divider()
                statusSection
                Divider()
                logsSection
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: controller.settings.showsDetailedSettings ? 580 : 360)
        .onAppear {
            controller.refreshPermissionStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "computermouse")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Mouse Gesture")
                    .font(.title2.weight(.semibold))
                Text(controller.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Enabled", isOn: monitoringBinding)
                .toggleStyle(.switch)
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                controller.hasRequiredPermissions ? "Accessibility enabled" : "Accessibility required",
                systemImage: controller.hasRequiredPermissions ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(controller.hasRequiredPermissions ? .green : .orange)

            Text(permissionStatusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    controller.requestAccessibilityPermission()
                } label: {
                    Label(
                        controller.hasRequiredPermissions ? "Permission Granted" : "Request Permission",
                        systemImage: "hand.raised"
                    )
                }
                .disabled(controller.hasRequiredPermissions)

                Button {
                    controller.openPermissionSettings()
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var permissionStatusText: String {
        let accessibility = controller.accessibilityTrusted ? "granted" : "missing"
        return "Accessibility: \(accessibility)."
    }

    private var gestureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Settings")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    Text("Trigger button")
                        .foregroundStyle(.secondary)

                    Stepper(
                        "Button \(controller.settings.triggerButtonNumber)",
                        value: triggerButtonBinding,
                        in: 2...31
                    )
                    .frame(maxWidth: 220, alignment: .leading)
                }

                GridRow {
                    Text("Drag distance")
                        .foregroundStyle(.secondary)

                    HStack {
                        Slider(
                            value: activationDistanceBinding,
                            in: 40...400,
                            step: 10
                        )
                        Text("\(Int(controller.settings.activationDistance)) px")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                    .frame(width: 280)
                }
            }
        }
    }

    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Application")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    Text("Monitor on app launch")
                        .foregroundStyle(.secondary)

                    Toggle("Monitor on app launch", isOn: startsAutomaticallyBinding)
                        .labelsHidden()
                }

                GridRow {
                    Text("Open at login")
                        .foregroundStyle(.secondary)

                    Toggle("Open at login", isOn: launchesAtLoginBinding)
                        .labelsHidden()
                }

                GridRow {
                    Text("Detailed settings")
                        .foregroundStyle(.secondary)

                    Toggle("Detailed settings", isOn: detailedSettingsBinding)
                        .labelsHidden()
                }
            }

            HStack {
                Button {
                    controller.resetSettings()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.headline)

            HStack(spacing: 18) {
                statusItem("Monitor", value: controller.isMonitoring ? "On" : "Off")
                statusItem("Last", value: controller.lastGesture)
                statusItem("Drag", value: dragText)
            }
        }
    }

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Test Log")
                    .font(.headline)

                Spacer()

                Button {
                    controller.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if controller.recentLogEntries.isEmpty {
                        Text("No logs yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controller.recentLogEntries, id: \.self) { entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 150)
        }
    }

    private func statusItem(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dragText: String {
        let xDistance = Int(controller.liveDrag.width.rounded())
        let yDistance = Int(controller.liveDrag.height.rounded())

        guard xDistance != 0 || yDistance != 0 else { return "Idle" }

        if abs(xDistance) >= abs(yDistance) {
            return "\(abs(xDistance)) px \(xDistance > 0 ? "right" : "left")"
        }

        return "\(abs(yDistance)) px \(yDistance > 0 ? "up" : "down")"
    }

    private var monitoringBinding: Binding<Bool> {
        Binding(
            get: { controller.isMonitoring },
            set: { isEnabled in
                if isEnabled {
                    controller.startMonitoring()
                } else {
                    controller.stopMonitoring()
                }
            }
        )
    }

    private var triggerButtonBinding: Binding<Int> {
        Binding(
            get: { controller.settings.triggerButtonNumber },
            set: { controller.setTriggerButtonNumber($0) }
        )
    }

    private var activationDistanceBinding: Binding<Double> {
        Binding(
            get: { controller.settings.activationDistance },
            set: { controller.setActivationDistance($0) }
        )
    }

    private var startsAutomaticallyBinding: Binding<Bool> {
        Binding(
            get: { controller.settings.startsAutomatically },
            set: { controller.setStartsAutomatically($0) }
        )
    }

    private var launchesAtLoginBinding: Binding<Bool> {
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
