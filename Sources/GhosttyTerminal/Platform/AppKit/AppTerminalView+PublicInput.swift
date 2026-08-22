//
//  AppTerminalView+PublicInput.swift
//  libghostty-spm
//
//  Public wrappers around `TerminalSurface` write paths so hosts can
//  inject bytes into the pty without reaching for internal API.
//

#if canImport(AppKit) && !canImport(UIKit)
    import AppKit

    extension AppTerminalView {
        /// Send raw UTF-8 text directly to the underlying pty (bypassing
        /// key translation). Use this for synthetic input like `\x1b[Z`
        /// (Shift+Tab / CSI Z) or multi-line paste-style injections.
        /// No-op when the surface has not been created yet.
        public func sendText(_ text: String) {
            surface?.sendText(text)
        }

        /// Invoke a named Ghostty binding action (e.g. "copy_to_clipboard",
        /// "clear_screen"). Returns true when the action dispatched.
        @discardableResult
        public func performBindingAction(_ action: String) -> Bool {
            surface?.performBindingAction(action) ?? false
        }

        /// Jump the viewport by a number of shell prompts.
        ///
        /// Negative offsets move toward older prompts and positive offsets move
        /// toward newer prompts. Prompt navigation requires shell integration.
        @discardableResult
        public func jumpToPrompt(by offset: Int16) -> Bool {
            surface?.jumpToPrompt(by: offset) ?? false
        }

        /// Reveal an absolute scrollback row, where zero is the first row.
        @discardableResult
        public func scrollToRow(_ row: UInt) -> Bool {
            surface?.scrollToRow(row) ?? false
        }

        /// Search the scrollback for `needle`, replacing any active search.
        /// Matching is literal (never a regex) and case-insensitive. Match
        /// highlighting is the core's job; progress arrives on
        /// ``TerminalSurfaceSearchDelegate``.
        ///
        /// Passing an empty needle cancels an active search (the delegate
        /// reports -1) but does not hide host UI — use ``endSearch()`` for
        /// that. With no search active it is a no-op returning false.
        @discardableResult
        public func startSearch(_ needle: String) -> Bool {
            performBindingAction("search:\(needle)")
        }

        /// Move to the next (or previous) match, wrapping at either end.
        /// A plain ``startSearch(_:)`` reports a total but never a selected
        /// index — the first `selected` only arrives once this is called.
        /// Returns false (and does nothing) with no active search.
        @discardableResult
        public func navigateSearch(next: Bool) -> Bool {
            performBindingAction("navigate_search:\(next ? "next" : "previous")")
        }

        /// End the active search and drop its highlights.
        @discardableResult
        public func endSearch() -> Bool {
            performBindingAction("end_search")
        }

        /// Whether the surface currently holds a text selection.
        public var hasSelection: Bool {
            surface?.hasSelection() == true
        }

        /// The current selection's text, if any. Lets a host implement the
        /// macOS "Use Selection for Find" (⌘E) idiom itself.
        public func readSelectionText() -> String? {
            surface?.readSelection()
        }
    }
#endif
