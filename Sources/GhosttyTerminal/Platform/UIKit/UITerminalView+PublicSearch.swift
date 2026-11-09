//
//  UITerminalView+PublicSearch.swift
//  libghostty-spm
//
//  Scrollback search and the selection's text, for hosts that draw their
//  own find bar. Progress comes back on ``TerminalSurfaceSearchDelegate``.
//

#if canImport(UIKit)
    import UIKit

    public extension UITerminalView {
        /// Search the scrollback for `needle`, replacing any active search.
        /// Matching is literal and case-insensitive; highlighting and the
        /// viewport jump are the core's. An empty needle cancels the active
        /// search without ending it — host UI stays up; ``endSearch()`` ends
        /// it. False, doing nothing, with no surface or no active search.
        @discardableResult
        func startSearch(_ needle: String) -> Bool {
            performBindingAction("search:\(needle)")
        }

        /// Move to the next (or previous) match, wrapping at either end. A
        /// plain ``startSearch(_:)`` reports a total but no selected match;
        /// the first one arrives after this. False with no active search.
        @discardableResult
        func navigateSearch(next: Bool) -> Bool {
            performBindingAction("navigate_search:\(next ? "next" : "previous")")
        }

        /// End the active search and drop its highlights.
        @discardableResult
        func endSearch() -> Bool {
            performBindingAction("end_search")
        }

        /// Whether the surface holds a text selection.
        var hasSelection: Bool {
            surface?.hasSelection() == true
        }

        /// The selection's text, nil with none — for a host's own "Use
        /// Selection for Find".
        func readSelectionText() -> String? {
            surface?.readSelection()
        }
    }
#endif
