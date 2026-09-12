//
//  TerminalInputAccessoryView.swift
//  libghostty-spm
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    import UIKit

    @MainActor
    final class TerminalInputAccessoryView: UIView, UIScrollViewDelegate {
        weak var terminalView: UITerminalView?

        var style: TerminalInputAccessoryStyle = .default {
            didSet { refreshContent() }
        }

        private let barHeight: CGFloat = 52
        private let buttonSize: CGFloat = 36

        private lazy var blurView = UIVisualEffectView(
            effect: makeBarEffect()
        )
        private let scrollView = UIScrollView()
        private let stackView = UIStackView()
        private var blurLeadingConstraint: NSLayoutConstraint?
        private var blurTrailingConstraint: NSLayoutConstraint?
        private var blurTopConstraint: NSLayoutConstraint?
        private var blurBottomConstraint: NSLayoutConstraint?
        private let pinnedStackView = UIStackView()
        /// Edge fades on the scrolling run: the mask goes transparent over
        /// the last `fadeWidth` points on a side that still has content
        /// beyond it, so a run wider than the bar reads as scrollable
        /// instead of simply ending at the divider.
        private let runFadeMask = CAGradientLayer()
        private let fadeWidth: CGFloat = 56
        private var pinnedDivider: UIView?
        private var keyButtons: [AccessoryButton] = []
        private var modifierButtons: [(TerminalStickyModifierState.Modifier, AccessoryButton)] = []
        /// Buttons of the pinned trailing group: tracked apart from
        /// `keyButtons` because layer pushes rebuild the scrolling run
        /// (and its tracking) while the pinned group stays.
        private var pinnedKeyButtons: [AccessoryButton] = []
        private var pinnedModifierButtons: [(TerminalStickyModifierState.Modifier, AccessoryButton)] = []
        /// Which arranged list `makeView(for:)` is currently tracking into.
        private var buildingPinned = false
        /// (run → divider, run → bar edge): the first is active only while
        /// the pinned group has content.
        private var pinnedTrailingConstraints: (NSLayoutConstraint, NSLayoutConstraint)?

        init(terminalView: UITerminalView) {
            self.terminalView = terminalView
            super.init(
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 0,
                    height: Self.preferredHeight(for: barHeight)
                )
            )
            autoresizingMask = .flexibleWidth
            setupViews()
            applyBarChrome()
            refreshContent()
            terminalView.stickyModifiers.onChange = { [weak self] in
                self?.refreshContent()
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight)
        }

        func refreshContent() {
            let hasMarkedText = terminalView?.inputHandler.hasMarkedText ?? false
            let shiftActivation = terminalView?.stickyModifiers.shift ?? .inactive
            let ctrlActivation = terminalView?.stickyModifiers.ctrl ?? .inactive
            let altActivation = terminalView?.stickyModifiers.alt ?? .inactive
            let commandActivation = terminalView?.stickyModifiers.command ?? .inactive

            (keyButtons + pinnedKeyButtons).forEach { $0.applyRegularStyle(style) }

            for (modifier, button) in modifierButtons + pinnedModifierButtons {
                let activation = switch modifier {
                case .shift: shiftActivation
                case .ctrl: ctrlActivation
                case .alt: altActivation
                case .command: commandActivation
                }
                button.applyModifierStyle(activation, isDisabled: hasMarkedText, style: style)
            }
        }

        /// Host-driven rebuild (`inputAccessoryItems` didSet): any pushed
        /// layer is stale against the new item set, so the stack resets.
        func rebuildContent() {
            pushedLayers.removeAll()
            rebuildEffectiveContent()
        }

        /// Host-driven rebuild of the fixed trailing group
        /// (`pinnedInputAccessoryItems` didSet). Independent of the layer
        /// stack: a pushed layer swaps the scrolling run only.
        func rebuildPinnedContent() {
            pinnedStackView.arrangedSubviews.forEach { view in
                pinnedStackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            pinnedKeyButtons.removeAll()
            pinnedModifierButtons.removeAll()

            let items = terminalView?.pinnedInputAccessoryItems ?? []
            buildingPinned = true
            let views = items.map(makeView(for:))
            buildingPinned = false
            views.forEach { pinnedStackView.addArrangedSubview($0) }

            // The separator between the run and the group exists only
            // while the group has content; an empty group also gives its
            // trailing padding back to the run.
            pinnedDivider?.isHidden = items.isEmpty
            pinnedStackView.isHidden = items.isEmpty
            if let (runToDivider, runToEdge) = pinnedTrailingConstraints {
                runToEdge.isActive = items.isEmpty
                runToDivider.isActive = !items.isEmpty
            }
            refreshContent()
        }

        // MARK: - Layers

        /// Sub-layers pushed by `.layer` items; the visible content is the
        /// top of the stack, or the host's items at the root.
        private var pushedLayers: [[TerminalInputAccessoryItem]] = []

        private func pushLayer(_ items: [TerminalInputAccessoryItem]) {
            pushedLayers.append(items)
            rebuildEffectiveContent()
        }

        private func popLayer() {
            guard !pushedLayers.isEmpty else { return }
            pushedLayers.removeLast()
            rebuildEffectiveContent()
        }

        private func rebuildEffectiveContent() {
            stackView.arrangedSubviews.forEach { view in
                stackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            keyButtons.removeAll()
            modifierButtons.removeAll()

            var views: [UIView] = []
            if !pushedLayers.isEmpty {
                views.append(makeTrackedBackButton())
                views.append(makeDivider())
            }
            let items = pushedLayers.last
                ?? terminalView?.inputAccessoryItems
                ?? TerminalInputAccessoryItem.defaultItems
            views.append(contentsOf: items.map(makeView(for:)))
            addArrangedViews(views)
            refreshContent()
            // Each layer reads from its leading edge, wherever the
            // previous one was scrolled to.
            scrollView.contentOffset = .zero
        }

        private func makeTrackedBackButton() -> AccessoryButton {
            let button = makeActionButton(title: "Back", systemImage: "chevron.backward") { [weak self] in
                self?.popLayer()
            }
            track(button)
            return button
        }

        private func setupViews() {
            backgroundColor = .clear

            blurView.translatesAutoresizingMaskIntoConstraints = false
            blurView.clipsToBounds = true
            addSubview(blurView)

            let leading = blurView.leadingAnchor.constraint(equalTo: leadingAnchor)
            let trailing = blurView.trailingAnchor.constraint(equalTo: trailingAnchor)
            let top = blurView.topAnchor.constraint(equalTo: topAnchor)
            let bottom = blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
            blurLeadingConstraint = leading
            blurTrailingConstraint = trailing
            blurTopConstraint = top
            blurBottomConstraint = bottom

            NSLayoutConstraint.activate([
                leading,
                trailing,
                top,
                bottom,
                blurView.heightAnchor.constraint(equalToConstant: barHeight),
            ])

            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = true
            scrollView.clipsToBounds = true
            scrollView.delegate = self
            runFadeMask.startPoint = CGPoint(x: 0, y: 0.5)
            runFadeMask.endPoint = CGPoint(x: 1, y: 0.5)
            scrollView.layer.mask = runFadeMask
            blurView.contentView.addSubview(scrollView)

            // Pinned trailing group: divider + its own stack, laid out
            // OUTSIDE the scroll view so the run scrolls underneath it.
            // Both collapse to nothing while the group is empty.
            let divider = makeDivider()
            pinnedDivider = divider
            pinnedStackView.translatesAutoresizingMaskIntoConstraints = false
            pinnedStackView.axis = .horizontal
            pinnedStackView.alignment = .center
            pinnedStackView.spacing = 8
            blurView.contentView.addSubview(divider)
            blurView.contentView.addSubview(pinnedStackView)

            NSLayoutConstraint.activate([
                pinnedStackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -10),
                pinnedStackView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
                divider.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
                divider.trailingAnchor.constraint(equalTo: pinnedStackView.leadingAnchor, constant: -8),
            ])
            // Hidden views keep their frame in plain Auto Layout, so the
            // run's trailing edge is tied to the divider only through a
            // constraint that is swapped by visibility below.
            let runToDivider = scrollView.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -2)
            let runToEdge = scrollView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor)
            runToDivider.priority = .required
            runToEdge.priority = .defaultHigh
            pinnedTrailingConstraints = (runToDivider, runToEdge)

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
                runToEdge,
                scrollView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            ])

            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.spacing = 8
            scrollView.addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 10),
                stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -10),
                stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            ])

            rebuildContent()
            rebuildPinnedContent()
        }

        private func addArrangedViews(_ views: [UIView]) {
            views.forEach { stackView.addArrangedSubview($0) }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateRunFade()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateRunFade()
        }

        /// Recomputes the mask from the run's scroll position. Pure
        /// geometry, no animation — the mask has to track the finger.
        private func updateRunFade() {
            let bounds = scrollView.bounds
            guard bounds.width > 0 else { return }
            let overflow = scrollView.contentSize.width - bounds.width
            let offset = scrollView.contentOffset.x
            let fadeLeading = overflow > 1 && offset > 1
            let fadeTrailing = overflow > 1 && offset < overflow - 1

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            runFadeMask.frame = bounds
            // Two stops per side: the fade drops to a quarter halfway in,
            // so most of the band reads as "cut off" rather than a faint
            // vignette a glance can miss.
            let opaque = UIColor.black.cgColor
            let dim = UIColor.black.withAlphaComponent(0.25).cgColor
            let clear = UIColor.clear.cgColor
            let fade = Double(min(fadeWidth / bounds.width, 0.45))
            runFadeMask.colors = [
                fadeLeading ? clear : opaque, fadeLeading ? dim : opaque, opaque,
                opaque, fadeTrailing ? dim : opaque, fadeTrailing ? clear : opaque,
            ]
            runFadeMask.locations = [
                0, NSNumber(value: fade / 2), NSNumber(value: fade),
                NSNumber(value: 1 - fade), NSNumber(value: 1 - fade / 2), 1,
            ]
            CATransaction.commit()
        }

        private func makeDivider() -> UIView {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .secondaryLabel.withAlphaComponent(0.28)
            view.layer.cornerRadius = 3
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: 6),
                view.heightAnchor.constraint(equalToConstant: 6),
            ])
            return view
        }

        private func makeView(for item: TerminalInputAccessoryItem) -> UIView {
            switch item {
            case .esc:
                makeTrackedKeyButton(title: "Escape", systemImage: "escape", key: .esc)

            case .shift:
                makeTrackedModifierButton(title: "Shift", systemImage: "shift", modifier: .shift)

            case .ctrl:
                makeTrackedModifierButton(title: "Control", systemImage: "control", modifier: .ctrl)

            case .alt:
                makeTrackedModifierButton(title: "Option", systemImage: "option", modifier: .alt)

            case .command:
                makeTrackedModifierButton(title: "Command", systemImage: "command", modifier: .command)

            case .tab:
                makeTrackedKeyButton(title: "Tab", systemImage: "arrow.right.to.line", key: .tab)

            case .arrowLeft:
                makeTrackedKeyButton(title: "Left", systemImage: "arrowtriangle.left.fill", key: .arrowLeft)

            case .arrowUp:
                makeTrackedKeyButton(title: "Up", systemImage: "arrowtriangle.up.fill", key: .arrowUp)

            case .arrowDown:
                makeTrackedKeyButton(title: "Down", systemImage: "arrowtriangle.down.fill", key: .arrowDown)

            case .arrowRight:
                makeTrackedKeyButton(title: "Right", systemImage: "arrowtriangle.right.fill", key: .arrowRight)

            case let .symbol(symbol):
                makeTrackedKeyButton(title: symbol, key: .symbol(symbol))

            case .paste:
                makeTrackedKeyButton(title: "Paste", systemImage: "doc.on.clipboard", key: .paste)

            case .dismissKeyboard:
                makeTrackedKeyButton(title: "Hide Keyboard", systemImage: "keyboard.chevron.compact.down", key: .dismissKeyboard)

            case let .custom(id, title, systemImage):
                makeTrackedCustomButton(id: id, title: title, systemImage: systemImage)

            case let .layer(title, systemImage, items):
                makeTrackedLayerButton(title: title, systemImage: systemImage, items: items)

            case .divider:
                makeDivider()
            }
        }

        private func makeTrackedLayerButton(
            title: String,
            systemImage: String?,
            items: [TerminalInputAccessoryItem]
        ) -> AccessoryButton {
            let button = makeActionButton(title: title, systemImage: systemImage) { [weak self] in
                self?.pushLayer(items)
            }
            track(button)
            return button
        }

        private func makeTrackedCustomButton(
            id: String,
            title: String,
            systemImage: String?
        ) -> AccessoryButton {
            let button = makeActionButton(title: title, systemImage: systemImage) { [weak terminalView] in
                terminalView?.onCustomAccessoryItem?(id)
            }
            // A host-provided menu wins over tap dispatch: single tap
            // presents it (showsMenuAsPrimaryAction suppresses the
            // touchUpInside handler above).
            if let menu = terminalView?.onCustomAccessoryItemMenu?(id) {
                button.menu = menu
                button.showsMenuAsPrimaryAction = true
            }
            track(button)
            return button
        }

        private func makeTrackedModifierButton(
            title: String,
            systemImage: String,
            modifier: TerminalStickyModifierState.Modifier
        ) -> AccessoryButton {
            let button = makeModifierButton(
                title: title,
                systemImage: systemImage,
                modifier: modifier
            )
            if buildingPinned {
                pinnedModifierButtons.append((modifier, button))
            } else {
                modifierButtons.append((modifier, button))
            }
            return button
        }

        private func makeTrackedKeyButton(
            title: String,
            systemImage: String? = nil,
            key: TerminalInputBarKey
        ) -> AccessoryButton {
            let button = makeKeyButton(title: title, systemImage: systemImage, key: key)
            track(button)
            return button
        }

        private func track(_ button: AccessoryButton) {
            if buildingPinned {
                pinnedKeyButtons.append(button)
            } else {
                keyButtons.append(button)
            }
        }

        private func makeModifierButton(
            title: String,
            systemImage: String,
            modifier: TerminalStickyModifierState.Modifier
        ) -> AccessoryButton {
            let button = AccessoryButton(size: buttonSize) { [weak terminalView] in
                terminalView?.stickyModifiers.toggle(modifier)
            }
            button.accessibilityLabel = title
            button.setImage(UIImage(systemName: systemImage), for: .normal)
            return button
        }

        private func makeKeyButton(
            title: String,
            systemImage: String? = nil,
            key: TerminalInputBarKey
        ) -> AccessoryButton {
            makeActionButton(title: title, systemImage: systemImage) { [weak terminalView] in
                terminalView?.handleInputBarKey(key)
            }
        }

        private func makeActionButton(
            title: String,
            systemImage: String?,
            handler: @escaping () -> Void
        ) -> AccessoryButton {
            let button = AccessoryButton(size: buttonSize, handler: handler)
            button.accessibilityLabel = title

            // An unresolvable symbol name (newer than the OS) degrades to
            // the text rendering rather than an empty button.
            if let systemImage, let image = UIImage(systemName: systemImage) {
                button.setImage(image, for: .normal)
            } else {
                var configuration = UIButton.Configuration.plain()
                configuration.baseForegroundColor = .label
                configuration.title = title
                configuration.contentInsets = .zero
                configuration.attributedTitle = AttributedString(
                    title,
                    attributes: AttributeContainer([
                        .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                    ])
                )
                button.configuration = configuration
            }

            return button
        }

        private var preferredHeight: CGFloat {
            Self.preferredHeight(for: barHeight)
        }

        private var currentOuterPadding: UIEdgeInsets {
            if #available(iOS 26, *) {
                UIEdgeInsets(top: 0, left: 8, bottom: 8, right: 8)
            } else {
                .zero
            }
        }

        private func makeBarEffect() -> UIVisualEffect {
            if #available(iOS 26, *) {
                let effect = UIGlassEffect(style: .regular)
                effect.isInteractive = true
                return effect
            } else {
                return UIBlurEffect(style: .systemUltraThinMaterial)
            }
        }

        private func applyBarChrome() {
            let padding = currentOuterPadding
            blurLeadingConstraint?.constant = padding.left
            blurTrailingConstraint?.constant = -padding.right
            blurTopConstraint?.constant = padding.top
            blurBottomConstraint?.isActive = !isFloatingBarLayout

            blurView.effect = makeBarEffect()
            blurView.layer.cornerCurve = .continuous
            blurView.layer.cornerRadius = if #available(iOS 26, *) {
                barHeight / 2
            } else {
                0
            }

            invalidateIntrinsicContentSize()
        }

        private var isFloatingBarLayout: Bool {
            if #available(iOS 26, *) {
                true
            } else {
                false
            }
        }

        private static func preferredHeight(for barHeight: CGFloat) -> CGFloat {
            if #available(iOS 26, *) {
                barHeight + 8
            } else {
                barHeight
            }
        }
    }

    private final class AccessoryButton: UIButton {
        private let size: CGFloat
        private let handler: () -> Void
        private let lockIndicator = UIView()

        init(size: CGFloat, handler: @escaping () -> Void) {
            self.size = size
            self.handler = handler
            super.init(frame: .zero)

            translatesAutoresizingMaskIntoConstraints = false
            layer.cornerRadius = size / 2
            layer.cornerCurve = .continuous
            clipsToBounds = true

            tintColor = .label
            backgroundColor = UIColor.systemGray5.withAlphaComponent(0.92)

            titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            imageView?.contentMode = .scaleAspectFit

            NSLayoutConstraint.activate([
                widthAnchor.constraint(equalToConstant: size),
                heightAnchor.constraint(equalToConstant: size),
            ])

            lockIndicator.translatesAutoresizingMaskIntoConstraints = false
            lockIndicator.backgroundColor = tintColor
            lockIndicator.layer.cornerRadius = 1.5
            lockIndicator.isHidden = true
            addSubview(lockIndicator)

            NSLayoutConstraint.activate([
                lockIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
                lockIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
                lockIndicator.widthAnchor.constraint(equalToConstant: 14),
                lockIndicator.heightAnchor.constraint(equalToConstant: 3),
            ])

            addAction(UIAction { [weak self] _ in
                self?.handler()
            }, for: .touchUpInside)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func applyRegularStyle(_ style: TerminalInputAccessoryStyle) {
            isEnabled = true
            alpha = 1
            tintColor = style.regularForeground
            backgroundColor = style.regularBackground
            lockIndicator.isHidden = true
            lockIndicator.backgroundColor = tintColor
            configuration?.baseForegroundColor = tintColor
        }

        func applyModifierStyle(
            _ activation: TerminalStickyModifierState.Activation,
            isDisabled: Bool,
            style: TerminalInputAccessoryStyle
        ) {
            isEnabled = !isDisabled
            alpha = isDisabled && activation == .inactive ? 0.45 : 1

            let isActive = activation != .inactive
            tintColor = isActive ? style.activeForeground : style.regularForeground
            backgroundColor = isActive ? style.activeBackground : style.regularBackground
            lockIndicator.isHidden = activation != .locked
            lockIndicator.backgroundColor = tintColor
            configuration?.baseForegroundColor = tintColor
        }
    }
#endif
