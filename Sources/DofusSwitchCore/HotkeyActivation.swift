// Sources/DofusSwitchCore/HotkeyActivation.swift
import Foundation

/// Nombre minimum de sessions Dofus détectées pour que les raccourcis globaux
/// soient enregistrés auprès de Carbon.
public let hotkeyMinimumSessions: Int = 2

/// Règle d'activation effective des raccourcis globaux.
///
/// Les raccourcis sont enregistrés si et seulement si l'utilisateur les a
/// activés dans les préférences ET qu'au moins `hotkeyMinimumSessions`
/// sessions Dofus sont actuellement détectées.
public func shouldEnableHotkeys(preferredEnabled: Bool, sessionCount: Int) -> Bool {
    preferredEnabled && sessionCount >= hotkeyMinimumSessions
}
