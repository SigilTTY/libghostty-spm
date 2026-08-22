//
//  TerminalSurfaceViewDelegate.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

import CoreGraphics
import Foundation
import GhosttyKit

@MainActor
public protocol TerminalSurfaceViewDelegate: AnyObject {}

@MainActor
public protocol TerminalSurfaceTitleDelegate: TerminalSurfaceViewDelegate {
    func terminalDidChangeTitle(_ title: String)
}

@MainActor
public protocol TerminalSurfaceGridResizeDelegate: TerminalSurfaceViewDelegate {
    func terminalDidResize(_ size: TerminalGridMetrics)
}

@MainActor
public protocol TerminalSurfaceResizeDelegate: TerminalSurfaceViewDelegate {
    func terminalDidResize(columns: Int, rows: Int)
}

@MainActor
public protocol TerminalSurfaceFocusDelegate: TerminalSurfaceViewDelegate {
    func terminalDidChangeFocus(_ focused: Bool)
}

@MainActor
public protocol TerminalSurfaceBellDelegate: TerminalSurfaceViewDelegate {
    func terminalDidRingBell()
}

@MainActor
public protocol TerminalSurfaceCloseDelegate: TerminalSurfaceViewDelegate {
    func terminalDidClose(processAlive: Bool)
}

/// Scrollback search (ghostty 1.3+). The core owns the search itself — the
/// host owns the UI. `startSearch`/`endSearch` are requests from the core to
/// show or hide that UI (⌘F or ⌘E with ghostty's own bindings still in place,
/// or a `start_search` / `search_selection` binding action); the two counters
/// report progress of the search thread.
///
/// Sentinels and ordering, as observed against the 1.3.1 engine:
///  * `-1` on either counter means "no active search".
///  * A genuine zero-match search reports `total == 0`, so 0 and -1 are
///    distinct — but each new `search:` first emits a transient
///    `total = 0` / `selected = -1` reset before the real total lands. A
///    search-as-you-type UI must debounce, or it will flash "no results"
///    on every keystroke.
///  * `terminalDidUpdateSearchSelection` never fires for a plain `search:`.
///    The first selected index arrives only after a `navigate_search`.
@MainActor
public protocol TerminalSurfaceSearchDelegate: TerminalSurfaceViewDelegate {
    /// The core asks the host to show its find UI. `needle` is empty when the
    /// request carries no prefilled term.
    func terminalDidRequestSearchUI(needle: String)
    /// The core asks the host to hide its find UI. Also fires when the user
    /// presses Escape with the terminal focused and a search active — the
    /// binding is conditional, so Escape still reaches the pty otherwise.
    func terminalDidEndSearch()
    /// Total number of matches, or -1 when no search is active.
    func terminalDidUpdateSearchTotal(_ total: Int)
    /// Index of the currently selected match, or -1 when none.
    func terminalDidUpdateSearchSelection(_ selected: Int)
}

// MARK: - Extended action delegates

/// State of an OSC 9;4 / DECSET progress report.
public enum TerminalProgressState: Sendable {
    case remove
    case set
    case error
    case indeterminate
    case pause

    init?(_ raw: ghostty_action_progress_report_state_e) {
        switch raw {
        case GHOSTTY_PROGRESS_STATE_REMOVE: self = .remove
        case GHOSTTY_PROGRESS_STATE_SET: self = .set
        case GHOSTTY_PROGRESS_STATE_ERROR: self = .error
        case GHOSTTY_PROGRESS_STATE_INDETERMINATE: self = .indeterminate
        case GHOSTTY_PROGRESS_STATE_PAUSE: self = .pause
        default: return nil
        }
    }
}

/// OSC 9;4 progress report (state + 0-100 percent, nil percent when the
/// emitter didn't provide one — e.g. INDETERMINATE / REMOVE).
@MainActor
public protocol TerminalSurfaceProgressReportDelegate: TerminalSurfaceViewDelegate {
    func terminalDidReportProgress(state: TerminalProgressState, percent: Int?)
}

/// Fires when a shell-integration-aware command exits. `exitCode` is nil
/// when not reported; `duration` is the wall clock in nanoseconds.
@MainActor
public protocol TerminalSurfaceCommandFinishedDelegate: TerminalSurfaceViewDelegate {
    func terminalDidFinishCommand(exitCode: Int?, durationNanos: UInt64)
}

/// OSC 9 (iTerm2) / OSC 777 (rxvt-unicode) desktop notification.
/// Empty title/body surface as empty strings rather than nil.
@MainActor
public protocol TerminalSurfaceDesktopNotificationDelegate: TerminalSurfaceViewDelegate {
    func terminalDidRequestDesktopNotification(title: String, body: String)
}

public enum TerminalOpenURLKind: Sendable {
    case unknown
    case text
    case html

    init(_ raw: ghostty_action_open_url_kind_e) {
        switch raw {
        case GHOSTTY_ACTION_OPEN_URL_KIND_TEXT: self = .text
        case GHOSTTY_ACTION_OPEN_URL_KIND_HTML: self = .html
        default: self = .unknown
        }
    }
}

/// User activated (cmd-clicked) a hyperlink inside the terminal grid.
@MainActor
public protocol TerminalSurfaceOpenURLDelegate: TerminalSurfaceViewDelegate {
    func terminalDidRequestOpenURL(_ url: String, kind: TerminalOpenURLKind)
}

/// Mouse hovered over a recognized hyperlink. nil = hover ended / link lost.
@MainActor
public protocol TerminalSurfaceHoverLinkDelegate: TerminalSurfaceViewDelegate {
    func terminalDidUpdateHoverLink(_ url: String?)
}

/// OSC 7 working-directory update.
@MainActor
public protocol TerminalSurfacePwdDelegate: TerminalSurfaceViewDelegate {
    func terminalDidChangeWorkingDirectory(_ path: String)
}

/// User long-pressed to request a selection-page presentation.
public struct TerminalTextSelectionRequest: Sendable {
    /// Viewport text snapshot. Lines separated by `\n`.
    public let text: String

    /// Recommended pre-selection range in UTF-16 units, suitable for direct
    /// assignment to `UITextView.selectedRange`. `nil` means the host should
    /// `selectAll` instead.
    public let anchorRange: NSRange?

    /// Long-press point in the terminal view's coordinate space (points).
    /// Hosts may use this as a popover anchor.
    public let sourcePoint: CGPoint
}

@MainActor
public protocol TerminalSurfaceTextSelectionRequestDelegate: TerminalSurfaceViewDelegate {
    func terminalDidRequestTextSelection(_ request: TerminalTextSelectionRequest)
}

/// A user paste gesture (accessory-bar Paste, ⌘V, the responder-chain
/// paste action) found a pasteboard whose primary payload is not
/// prompt-ready text: either no text at all (image content copies), or
/// file URLs whose string representation is mere decoration (a Finder /
/// Files file copy carries the file's *name* as its string — pasting
/// that into a terminal serves nobody). The host decides what, if
/// anything, to do with the payload; the library never inspects
/// non-text pasteboard content itself.
///
/// Return `true` if the paste was taken over. Returning `false` falls
/// back to the legacy behavior — the string pastes if there is one,
/// otherwise the gesture stays a silent no-op.
///
/// Deliberately wired to user gestures ONLY — never to the runtime's
/// clipboard-read callback, which a remote application can drive via
/// OSC 52. Routing it there would let the remote trigger whatever the
/// host does with the pasteboard (e.g. upload an image) without any
/// user action.
@MainActor
public protocol TerminalSurfaceNonTextPasteDelegate: TerminalSurfaceViewDelegate {
    func terminalDidRequestNonTextPaste() -> Bool
}

/// Notifies a delegate when the underlying ``TerminalSurface`` is created or
/// torn down. Useful when a consumer needs surface-level APIs (e.g.
/// ``TerminalSurface/sendText(_:)``) reachable from outside the platform view.
@MainActor
public protocol TerminalSurfaceLifecycleDelegate: TerminalSurfaceViewDelegate {
    func terminalDidAttachSurface(_ surface: TerminalSurface)
    func terminalDidDetachSurface()
}
