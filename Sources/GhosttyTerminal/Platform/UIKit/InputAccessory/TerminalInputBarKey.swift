//
//  TerminalInputBarKey.swift
//  libghostty-spm
//

#if canImport(UIKit)
    #if !targetEnvironment(macCatalyst)
        import UIKit

        public enum TerminalInputAccessoryItem: Equatable, Sendable {
            case esc
            case ctrl
            case alt
            case command
            case tab
            case arrowLeft
            case arrowUp
            case arrowDown
            case arrowRight
            case symbol(String)
            /// A `symbol` key drawn as `presentation` instead of the text it
            /// sends — `"\u{1b}[A"` as "Up", a long command as a short name
            /// or an icon. It sends exactly what `symbol` would.
            case presentedSymbol(String, presentation: TerminalInputAccessoryItemPresentation)
            case paste
            case divider
            /// A host-defined button drawn with the built-in keys' chrome.
            /// When the view's `onCustomAccessoryItemMenu` returns a menu for
            /// `id`, a tap presents it; otherwise a tap calls
            /// `onCustomAccessoryItem` with `id`. The library attaches no
            /// behaviour and leaves sticky modifiers alone — a custom action
            /// is not a key. A nil (or unresolvable) `systemImage` draws
            /// `title` as text; `title` is always the accessibility label.
            case custom(id: String, title: String, systemImage: String?)
            /// A sub-layer of the bar: a tap swaps the bar's content for
            /// `items`, behind an automatic Back button. Layers nest; the
            /// stack resets whenever the host reassigns `inputAccessoryItems`.
            /// Sticky modifiers survive the switch — an armed Ctrl applies to
            /// the next key tapped inside the layer.
            case layer(title: String, systemImage: String?, items: [TerminalInputAccessoryItem])

            /// A key that sends `text` and is drawn as `presentation`; spelled
            /// like `symbol` so a layout reads as one list.
            public static func symbol(
                _ text: String,
                presentation: TerminalInputAccessoryItemPresentation,
            ) -> Self {
                .presentedSymbol(text, presentation: presentation)
            }

            /// The English name the accessory bar uses as the button's
            /// accessibility label; `symbol` returns its literal text, a
            /// presented one its label or its image's `accessibilityLabel`
            /// (else the text), and `divider` has none. Public so a host's
            /// bar-configuration UI can describe items without duplicating
            /// this table.
            public var title: String? {
                switch self {
                case .esc: "Escape"
                case .ctrl: "Control"
                case .alt: "Option"
                case .command: "Command"
                case .tab: "Tab"
                case .arrowLeft: "Left Arrow"
                case .arrowUp: "Up Arrow"
                case .arrowDown: "Down Arrow"
                case .arrowRight: "Right Arrow"
                case let .symbol(symbol): symbol
                case let .presentedSymbol(symbol, _):
                    switch presentation {
                    case let .text(label): label
                    case let .image(_, accessibilityLabel): accessibilityLabel ?? symbol
                    case nil: symbol
                    }
                case .paste: "Paste"
                case let .custom(_, title, _), let .layer(title, _, _): title
                case .divider: nil
                }
            }

            /// How the bar draws a text key: `symbol` as `.text` of all it
            /// sends, a presented one as given — except an empty `.text`,
            /// which shows the text it sends. `nil` for items drawn as glyphs
            /// or not drawn at all. Public so a host's bar-configuration UI
            /// draws keys the way the bar does.
            public var presentation: TerminalInputAccessoryItemPresentation? {
                switch self {
                case let .symbol(symbol): .text(symbol)
                case let .presentedSymbol(symbol, .text(label)) where label.isEmpty: .text(symbol)
                case let .presentedSymbol(_, presentation): presentation
                default: nil
                }
            }

            /// The label a text key shows (`presentation` when it is `.text`):
            /// one line, in a capsule that widens to fit. `nil` for a key drawn
            /// as an image or a glyph, and for items not drawn at all.
            public var buttonTitle: String? {
                guard case let .text(label) = presentation else { return nil }
                return label
            }

            /// The SF Symbol the accessory bar renders for this item; nil for
            /// items drawn as text (`symbol`) or non-buttons (`divider`). Public
            /// so a host's bar-configuration UI shows the same glyphs as the bar.
            public var systemImage: String? {
                switch self {
                case .esc: "escape"
                case .ctrl: "control"
                case .alt: "option"
                case .command: "command"
                case .tab: "arrow.right.to.line"
                case .arrowLeft: "arrowtriangle.left.fill"
                case .arrowUp: "arrowtriangle.up.fill"
                case .arrowDown: "arrowtriangle.down.fill"
                case .arrowRight: "arrowtriangle.right.fill"
                case .paste: "doc.on.clipboard"
                case let .custom(_, _, systemImage), let .layer(_, systemImage, _): systemImage
                case .symbol, .presentedSymbol, .divider: nil
                }
            }

            public static let defaultItems: [TerminalInputAccessoryItem] = [
                .esc,
                .tab,
                .ctrl,
                .alt,
                .command,
                .divider,
                .layer(
                    title: "Arrows",
                    // The radiating-arrows glyph, not "arrowkeys": four boxed
                    // keys read as clutter at button size.
                    systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                    items: defaultArrowLayerItems,
                ),
                .layer(title: "Symbols", systemImage: "number", items: defaultSymbolLayerItems),
                .divider,
                .paste,
            ]

            /// The arrow keys the default bar folds behind its "Arrows" key.
            public static let defaultArrowLayerItems: [TerminalInputAccessoryItem] = [
                .arrowLeft,
                .arrowUp,
                .arrowDown,
                .arrowRight,
            ]

            /// The symbols the default bar folds behind its "Symbols" key: the
            /// eight it once showed inline first, then the rest of the
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
        }
    #endif
#endif
