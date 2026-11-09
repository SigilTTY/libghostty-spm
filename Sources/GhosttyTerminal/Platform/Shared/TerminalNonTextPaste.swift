//
//  TerminalNonTextPaste.swift
//  libghostty-spm
//
//  Which paste gestures go to ``TerminalSurfaceNonTextPasteDelegate`` first.
//

#if canImport(UIKit)
    import UIKit
    import UniformTypeIdentifiers
#elseif canImport(AppKit)
    import AppKit
#endif

enum TerminalNonTextPaste {
    #if canImport(UIKit)
        /// Whether the general pasteboard's payload is something other than
        /// prompt-ready text: no string at all (an image, document data), or
        /// a file copy, whose string is only the file's display name. File
        /// URLs outrank the string. Metadata probes only — they never raise
        /// the paste-permission banner.
        @MainActor
        static func pasteboardPrefersHost(_ pasteboard: UIPasteboard = .general) -> Bool {
            if pasteboard.contains(pasteboardTypes: [UTType.fileURL.identifier]) {
                return true
            }
            return !pasteboard.hasStrings
        }

        /// ⌘V with no other modifier, the one hardware chord read as a paste
        /// gesture; a rebound paste key keeps the binding path.
        static func isPlainPasteChord(_ key: UIKey) -> Bool {
            guard key.keyCode == .keyboardV else { return false }
            return key.modifierFlags.intersection([.command, .shift, .alternate, .control]) == .command
        }
    #elseif canImport(AppKit)
        /// See the UIKit twin: file URLs outrank the string, otherwise a
        /// missing or empty string decides.
        static func pasteboardPrefersHost(_ pasteboard: NSPasteboard = .general) -> Bool {
            if pasteboard.types?.contains(.fileURL) == true {
                return true
            }
            return pasteboard.string(forType: .string)?.isEmpty ?? true
        }

        static func isPlainPasteChord(_ event: NSEvent) -> Bool {
            guard event.charactersIgnoringModifiers == "v" else { return false }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return mods.contains(.command) && mods.isDisjoint(with: [.shift, .option, .control])
        }
    #endif

    /// Offers a paste gesture to the host when the pasteboard prefers it.
    /// True when the host took the paste over.
    @MainActor
    static func offer(to delegate: (any TerminalSurfaceViewDelegate)?) -> Bool {
        guard let host = delegate as? any TerminalSurfaceNonTextPasteDelegate,
              pasteboardPrefersHost()
        else { return false }
        let handled = host.terminalDidRequestNonTextPaste()
        TerminalDebugLog.log(.input, "non-text paste offered to host handled=\(handled)")
        return handled
    }
}
