//
//  MouseGestureSettings.swift
//  mouseGesture
//
//  Created by Poulastaa Das on 18/06/26.
//

import Foundation

struct MouseGestureSettings: Equatable {
    var triggerButtonNumber: Int
    var activationDistance: Double
    var dominanceRatio: Double
    var startsAutomatically: Bool
    var launchesAtLogin: Bool
    var showsDetailedSettings: Bool

    static let defaults = MouseGestureSettings(
        triggerButtonNumber: 2,
        activationDistance: 140,
        dominanceRatio: 1.35,
        startsAutomatically: true,
        launchesAtLogin: true,
        showsDetailedSettings: false
    )
}

extension MouseGestureSettings {
    private enum DefaultsKey {
        static let triggerButtonNumber = "triggerButtonNumber"
        static let activationDistance = "activationDistance"
        static let dominanceRatio = "dominanceRatio"
        static let startsAutomatically = "startsAutomatically"
        static let launchesAtLogin = "launchesAtLogin"
        static let showsDetailedSettings = "showsDetailedSettings"
    }

    init(userDefaults: UserDefaults = .standard) {
        let base = Self.defaults

        let storedButtonNumber = userDefaults.object(forKey: DefaultsKey.triggerButtonNumber) == nil
            ? base.triggerButtonNumber
            : userDefaults.integer(forKey: DefaultsKey.triggerButtonNumber)
        triggerButtonNumber = Self.clampedButtonNumber(storedButtonNumber)

        let storedActivationDistance = userDefaults.object(forKey: DefaultsKey.activationDistance) == nil
            ? base.activationDistance
            : userDefaults.double(forKey: DefaultsKey.activationDistance)
        activationDistance = Self.clampedActivationDistance(storedActivationDistance)

        let storedDominanceRatio = userDefaults.object(forKey: DefaultsKey.dominanceRatio) == nil
            ? base.dominanceRatio
            : userDefaults.double(forKey: DefaultsKey.dominanceRatio)
        dominanceRatio = max(1.0, min(3.0, storedDominanceRatio))

        startsAutomatically = userDefaults.object(forKey: DefaultsKey.startsAutomatically) == nil
            ? base.startsAutomatically
            : userDefaults.bool(forKey: DefaultsKey.startsAutomatically)

        launchesAtLogin = userDefaults.object(forKey: DefaultsKey.launchesAtLogin) == nil
            ? base.launchesAtLogin
            : userDefaults.bool(forKey: DefaultsKey.launchesAtLogin)

        showsDetailedSettings = userDefaults.object(forKey: DefaultsKey.showsDetailedSettings) == nil
            ? base.showsDetailedSettings
            : userDefaults.bool(forKey: DefaultsKey.showsDetailedSettings)
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(triggerButtonNumber, forKey: DefaultsKey.triggerButtonNumber)
        userDefaults.set(activationDistance, forKey: DefaultsKey.activationDistance)
        userDefaults.set(dominanceRatio, forKey: DefaultsKey.dominanceRatio)
        userDefaults.set(startsAutomatically, forKey: DefaultsKey.startsAutomatically)
        userDefaults.set(launchesAtLogin, forKey: DefaultsKey.launchesAtLogin)
        userDefaults.set(showsDetailedSettings, forKey: DefaultsKey.showsDetailedSettings)
    }

    static func clampedButtonNumber(_ value: Int) -> Int {
        max(2, min(31, value))
    }

    static func clampedActivationDistance(_ value: Double) -> Double {
        max(40, min(400, value))
    }
}
