//
//  UITerminalView+Lifecycle.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/17.
//

#if canImport(UIKit)
    import UIKit

    extension UITerminalView {
        func setupApplicationLifecycleObservers() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }

        func syncApplicationActiveState() {
            core.setApplicationActive(
                UIApplication.shared.applicationState == .active
            )
        }

        @objc func applicationDidEnterBackground(_: Notification) {
            TerminalDebugLog.log(.lifecycle, "application did enter background")
            stopMomentumScrolling(sendTerminalEndEvent: false)
            core.setApplicationActive(false)
        }

        @objc func applicationDidBecomeActive(_: Notification) {
            TerminalDebugLog.log(.lifecycle, "application did become active")
            updateDisplayScale()
            updateColorScheme()
            core.setApplicationActive(true)
        }

        override open func didMoveToWindow() {
            super.didMoveToWindow()
            TerminalDebugLog.log(
                .lifecycle,
                "didMoveToWindow attached=\(window != nil)"
            )
            updateDisplayScale()
            if window != nil {
                core.rebuildIfReady()
                updateColorScheme()
                core.startDisplayLink()
                // Defer sublayer frame and metrics sync to the next runloop
                // so that AutoLayout has resolved final bounds.
                DispatchQueue.main.async { [weak self] in
                    guard let self, window != nil else { return }
                    updateSublayerFrames()
                    core.fitToSize()
                }
            } else {
                core.stopDisplayLink()
                core.freeSurface()
            }
        }

        override open func layoutSubviews() {
            super.layoutSubviews()
            TerminalDebugLog.log(
                .metrics,
                "layoutSubviews bounds=\(NSCoder.string(for: bounds))"
            )
            updateSublayerFrames()
            core.fitToSize()
        }

        func resolvedDisplayScale() -> CGFloat {
            if let screen = window?.screen {
                return screen.nativeScale
            }
            if traitCollection.displayScale > 0 {
                return traitCollection.displayScale
            }
            return UIScreen.main.nativeScale
        }

        func updateDisplayScale() {
            let scale = resolvedDisplayScale()
            TerminalDebugLog.log(
                .metrics,
                "updateDisplayScale scale=\(String(format: "%.2f", scale))"
            )
            contentScaleFactor = scale
            layer.contentsScale = scale
            updateSublayerFrames()
        }

        /// Detaches and disarms ghostty's render layers. Runs via the
        /// coordinator's neutralizeRenderLayers hook right before EVERY
        /// ghostty_surface_free (window exit, controller/config rebuild,
        /// deinit). The Zig IOSurfaceLayer subclass stores the renderer
        /// pointer in its display_cb/display_ctx ivars, never clears them,
        /// and has needsDisplayOnBoundsChange set — so a layer that
        /// survives the free (still in a tree, or referenced by an
        /// in-flight CoreAnimation commit) gets -display later and walks
        /// into the freed renderer: object_getClass / os_unfair_lock
        /// corruption aborts under CA::Context::commit_transaction,
        /// near-100% when output was streaming (closing a session
        /// mid-connect). Clearing the ivars makes any late -display a
        /// no-op; removing the layer stops future commits from reaching
        /// it at all.
        func neutralizeGhosttyLayers() {
            guard let sublayers = layer.sublayers else { return }
            for sublayer in sublayers {
                for ivarName in ["display_cb", "display_ctx"] {
                    if let cls = object_getClass(sublayer),
                       let ivar = class_getInstanceVariable(cls, ivarName) {
                        object_setIvar(sublayer, ivar, nil)
                    }
                }
                sublayer.delegate = nil
                sublayer.removeFromSuperlayer()
            }
        }

        func updateSublayerFrames() {
            let scale = resolvedDisplayScale()
            contentScaleFactor = scale
            layer.contentsScale = scale
            guard let sublayers = layer.sublayers else { return }
            for sublayer in sublayers {
                sublayer.frame = bounds
                sublayer.contentsScale = scale
            }
        }

        func enforceSublayerScale() {
            let scale = resolvedDisplayScale()
            guard let sublayers = layer.sublayers else { return }
            for sublayer in sublayers {
                if sublayer.contentsScale != scale {
                    sublayer.contentsScale = scale
                }
                if sublayer.frame != bounds {
                    sublayer.frame = bounds
                }
            }
        }

        public func fitToSize() {
            core.fitToSize()
        }

        override open func traitCollectionDidChange(
            _ previousTraitCollection: UITraitCollection?
        ) {
            super.traitCollectionDidChange(previousTraitCollection)
            updateDisplayScale()
            if traitCollection.hasDifferentColorAppearance(
                comparedTo: previousTraitCollection
            ) {
                updateColorScheme()
            }
        }

        func updateColorScheme() {
            let style = traitCollection.userInterfaceStyle
            let scheme: TerminalColorScheme = style == .dark ? .dark : .light
            TerminalDebugLog.log(.lifecycle, "updateColorScheme scheme=\(scheme)")
            surface?.setColorScheme(scheme.ghosttyValue)
            if let controller,
               let viewState = delegate as? TerminalViewState,
               viewState.controller === controller
            {
                viewState.adopt(terminalColorScheme: scheme)
            } else {
                controller?.setColorScheme(scheme)
            }
        }

        @discardableResult
        override open func becomeFirstResponder() -> Bool {
            let result = super.becomeFirstResponder()
            core.setFocus(true)
            onFocusChange?(true)
            return result
        }

        @discardableResult
        override open func resignFirstResponder() -> Bool {
            let result = super.resignFirstResponder()
            core.setFocus(false)
            onFocusChange?(false)
            return result
        }
    }
#endif
