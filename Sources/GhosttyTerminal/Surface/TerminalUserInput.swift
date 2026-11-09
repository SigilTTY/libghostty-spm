//
//  TerminalUserInput.swift
//  libghostty-spm
//
//  User input captured after input-method resolution, so a host can deliver
//  the same input to another surface (SigilTTY's Broadcast Input).
//

import Foundation
import GhosttyKit

/// One unit of user input a platform view is delivering to its terminal,
/// captured after input-method resolution — what a host needs to deliver the
/// same input to another surface.
///
/// Only the view's own user-input paths report it (keyboard, committed IME
/// text, paste gestures), through ``TerminalSurfaceUserInputDelegate``. Host
/// injection (`paste(text:)`, `sendKey`, `replayUserInput`) never does, so a
/// replay cannot echo back; and what the core writes on its own — replies to
/// terminal queries, mouse and focus reports — is not user input and never
/// appears here.
public enum TerminalUserInput: Equatable, Sendable {
    /// A key event handed to the core's key encoder. A receiving surface
    /// encodes it under its own terminal modes (cursor-key mode,
    /// modifyOtherKeys, the kitty keyboard protocol), which is why the event
    /// travels rather than the bytes it produced here.
    case key(TerminalKeyInput)
    /// Text committed outside a key event — an input-method candidate picked
    /// with the mouse, the Character Viewer. Delivered through the paste
    /// pipeline, like the original.
    case text(String)
    /// The text of a paste gesture (⌘V, the responder-chain `paste:`), as the
    /// paste delivers it (a file URL as its escaped path). A receiving
    /// surface pastes it through its own pipeline, so bracketed paste follows
    /// that terminal's mode. A pasteboard the host took as a non-text paste
    /// is never reported, and neither is the ⌘V key.
    case paste(String)
}

/// A self-contained copy of `ghostty_input_key_s`: it owns its text, so it
/// outlives the C call it was captured from.
public struct TerminalKeyInput: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case press
        case release
        case repeated
    }

    public var action: Action
    /// The platform virtual keycode, exactly as the core received it.
    public var keycode: UInt32
    public var modifiers: TerminalInputModifiers
    public var consumedModifiers: TerminalInputModifiers
    /// What the key produced after input-method and layout translation.
    public var text: String?
    public var unshiftedCodepoint: UInt32
    /// Set while an input method is composing. The core does not encode
    /// these; the composition lives in the view's preedit.
    public var composing: Bool

    public init(
        action: Action,
        keycode: UInt32,
        modifiers: TerminalInputModifiers = [],
        consumedModifiers: TerminalInputModifiers = [],
        text: String? = nil,
        unshiftedCodepoint: UInt32 = 0,
        composing: Bool = false,
    ) {
        self.action = action
        self.keycode = keycode
        self.modifiers = modifiers
        self.consumedModifiers = consumedModifiers
        self.text = text
        self.unshiftedCodepoint = unshiftedCodepoint
        self.composing = composing
    }
}

extension TerminalKeyInput {
    /// `text` travels separately: inside the C event it is a borrowed
    /// pointer, valid only for the call that carried it.
    init(_ event: ghostty_input_key_s, text: String?) {
        self.init(
            action: Action(event.action),
            keycode: event.keycode,
            modifiers: TerminalInputModifiers(rawValue: event.mods.rawValue),
            consumedModifiers: TerminalInputModifiers(rawValue: event.consumed_mods.rawValue),
            text: text,
            unshiftedCodepoint: event.unshifted_codepoint,
            composing: event.composing,
        )
    }

    /// Calls `body` with the equivalent C event. Its text pointer is valid
    /// only inside `body`.
    func withGhosttyEvent<Result>(_ body: (ghostty_input_key_s) -> Result) -> Result {
        var event = ghostty_input_key_s()
        event.action = action.ghosttyAction
        event.mods = modifiers.ghosttyMods
        event.consumed_mods = consumedModifiers.ghosttyMods
        event.keycode = keycode
        event.unshifted_codepoint = unshiftedCodepoint
        event.composing = composing
        guard let text else {
            event.text = nil
            return body(event)
        }
        return text.withCString { pointer in
            event.text = pointer
            return body(event)
        }
    }
}

private extension TerminalKeyInput.Action {
    init(_ action: ghostty_input_action_e) {
        switch action {
        case GHOSTTY_ACTION_RELEASE: self = .release
        case GHOSTTY_ACTION_REPEAT: self = .repeated
        default: self = .press
        }
    }

    var ghosttyAction: ghostty_input_action_e {
        switch self {
        case .press: GHOSTTY_ACTION_PRESS
        case .release: GHOSTTY_ACTION_RELEASE
        case .repeated: GHOSTTY_ACTION_REPEAT
        }
    }
}
