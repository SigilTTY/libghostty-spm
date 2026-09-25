//
//  TerminalSurfaceCoordinator+UserInput.swift
//  libghostty-spm
//

import Foundation

extension TerminalSurfaceCoordinator {
    /// Delivers input captured on another surface as if it had been typed
    /// here: key events through this surface's own encoder, text and pastes
    /// through its paste pipeline, bytes straight to the in-memory backend.
    ///
    /// Requires a surface for every kind, bytes included: a view that was
    /// never on screen would otherwise take the control keys and drop the
    /// letters between them.
    func replay(_ input: TerminalUserInput) -> Bool {
        guard let surface else { return false }
        switch input {
        case let .key(key):
            _ = key.withGhosttyEvent { event in
                surface.sendKeyEvent(event)
            }
        case let .bytes(data):
            guard case let .inMemory(session) = configuration.backend else {
                return false
            }
            session.sendInput(data)
        case let .text(text), let .paste(text):
            surface.sendText(text)
        }
        return true
    }
}
