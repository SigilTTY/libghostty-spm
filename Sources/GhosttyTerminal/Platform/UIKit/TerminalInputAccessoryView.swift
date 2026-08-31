//
//  TerminalInputAccessoryView.swift
//  libghostty-spm
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    import UIKit

    @MainActor
    final class TerminalInputAccessoryView: UIView {
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
        private var keyButtons: [AccessoryButton] = []
        private var modifierButtons: [(TerminalStickyModifierState.Modifier, AccessoryButton)] = []

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
            let ctrlActivation = terminalView?.stickyModifiers.ctrl ?? .inactive
            let altActivation = terminalView?.stickyModifiers.alt ?? .inactive
            let commandActivation = terminalView?.stickyModifiers.command ?? .inactive

            keyButtons.forEach { $0.applyRegularStyle(style) }

            for (modifier, button) in modifierButtons {
                let activation = switch modifier {
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
            keyButtons.append(button)
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
            blurView.contentView.addSubview(scrollView)

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
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
        }

        private func addArrangedViews(_ views: [UIView]) {
            views.forEach { stackView.addArrangedSubview($0) }
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
            keyButtons.append(button)
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
            keyButtons.append(button)
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
            modifierButtons.append((modifier, button))
            return button
        }

        private func makeTrackedKeyButton(
            title: String,
            systemImage: String? = nil,
            key: TerminalInputBarKey
        ) -> AccessoryButton {
            let button = makeKeyButton(title: title, systemImage: systemImage, key: key)
            keyButtons.append(button)
            return button
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
