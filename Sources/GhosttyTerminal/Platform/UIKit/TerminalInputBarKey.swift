//
//  TerminalInputBarKey.swift
//  libghostty-spm
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    public enum TerminalInputAccessoryItem: Equatable, Sendable {
        case esc
        /// Sticky Shift — the modifier the TUIs want on Tab (Shift+Tab
        /// cycles modes in Claude Code and most curses forms) and Enter
        /// (newline-without-submit where the app supports it). Applies to
        /// the next key like Ctrl/Alt/⌘; a lone letter comes out uppercase.
        case shift
        case ctrl
        case alt
        case command
        case tab
        case arrowLeft
        case arrowUp
        case arrowDown
        case arrowRight
        case symbol(String)
        case paste
        /// Drops the software keyboard: the terminal view resigns first
        /// responder. Sticky modifiers are left untouched — dismissing
        /// the keyboard is not a key.
        case dismissKeyboard
        case divider
        /// A host-defined button rendered with the same chrome as the
        /// built-in keys. If the view's `onCustomAccessoryItemMenu`
        /// returns a menu for `id`, a single tap presents it; otherwise
        /// tapping calls `onCustomAccessoryItem` with `id`. The library
        /// attaches no behavior of its own (sticky modifiers are left
        /// untouched — a custom action is not a key). `systemImage` nil
        /// renders `title` as monospaced text instead of an SF Symbol;
        /// `title` always doubles as the accessibility label.
        case custom(id: String, title: String, systemImage: String?)
        /// A sub-layer of the bar: tapping swaps the bar's content for
        /// `items`, prefixed with an automatic back button that returns
        /// to the layer above. Layers nest; the stack resets whenever
        /// the host reassigns `inputAccessoryItems`. Sticky modifiers
        /// survive the switch — an armed Ctrl still applies to the next
        /// key tapped inside the layer.
        case layer(title: String, systemImage: String?, items: [TerminalInputAccessoryItem])

        public static let defaultItems: [TerminalInputAccessoryItem] = [
            .esc,
            .tab,
            .shift,
            .ctrl,
            .alt,
            .command,
            .divider,
            .layer(
                title: "Arrows",
                // The radiating-arrows glyph, not "arrowkeys" — four boxed
                // keys read as clutter at button size. iOS 16+; earlier
                // systems get the text fallback.
                systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                items: defaultArrowLayerItems
            ),
            .layer(title: "Symbols", systemImage: "number", items: defaultSymbolLayerItems),
            .divider,
            .paste,
        ]

        /// The arrow keys the default bar folds behind its "Arrows"
        /// layer key.
        public static let defaultArrowLayerItems: [TerminalInputAccessoryItem] = [
            .arrowLeft,
            .arrowUp,
            .arrowDown,
            .arrowRight,
        ]

        /// The symbols the default bar folds behind its "Symbols" layer
        /// key — the original inline eight first, then the rest of the
        /// shell-useful ASCII set, grouped by shape.
        public static let defaultSymbolLayerItems: [TerminalInputAccessoryItem] = [
            .symbol("|"),
            .symbol("/"),
            .symbol("~"),
            .symbol("-"),
            .symbol("_"),
            .symbol("`"),
            .symbol("'"),
            .symbol("\""),
            .divider,
            .symbol("!"),
            .symbol("@"),
            .symbol("#"),
            .symbol("$"),
            .symbol("%"),
            .symbol("^"),
            .symbol("&"),
            .symbol("*"),
            .divider,
            .symbol("("),
            .symbol(")"),
            .symbol("["),
            .symbol("]"),
            .symbol("{"),
            .symbol("}"),
            .symbol("<"),
            .symbol(">"),
            .divider,
            .symbol(";"),
            .symbol(":"),
            .symbol("="),
            .symbol("+"),
            .symbol("\\"),
            .symbol("?"),
        ]
    }

    enum TerminalInputBarKey {
        case esc
        case tab
        case arrowLeft
        case arrowUp
        case arrowDown
        case arrowRight
        case symbol(String)
        case paste
        case dismissKeyboard
    }
#endif
