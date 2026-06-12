//
//  MainTabBarController.swift
//  ClaudeBugPoC
//

import UIKit

final class MainTabBarController: UITabBarController {

    // MARK: - Private
    private lazy var floatingButton: AIFloatingButton = {
        let button = AIFloatingButton.create()
        button.delegate = self
        return button
    }()

    private lazy var floatingMenu: AIFloatingMenuView = {
        let menu = AIFloatingMenuView.create()
        menu.delegate = self
        menu.isHidden = true
        return menu
    }()

    private var inspectorOverlay: AIInspectorOverlay?
    private var didPlaceFloatingButton = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        viewControllers = makeTabs()
        view.addSubview(floatingMenu)
        view.addSubview(floatingButton)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionFloatingButtonIfNeeded()
        view.bringSubviewToFront(floatingMenu)
        view.bringSubviewToFront(floatingButton)
        if let overlay = inspectorOverlay {
            view.bringSubviewToFront(overlay)
            view.bringSubviewToFront(floatingButton)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if !floatingMenu.isHidden, let touch = touches.first {
            let point = touch.location(in: view)
            if !floatingMenu.frame.contains(point), !floatingButton.frame.contains(point) {
                hideFloatingMenu()
            }
        }
    }

    // MARK: - Setup
    private func configureAppearance() {
        view.backgroundColor = .systemBackground
        tabBar.tintColor = .label
        tabBar.unselectedItemTintColor = .secondaryLabel

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    private func makeTabs() -> [UIViewController] {
        return [
            wrap(
                PokemonListViewController(),
                title: LocalizationKey.Tab.pokemon.localize,
                systemImage: "circle.hexagongrid.fill",
                identifier: "pokemonTab"
            ),
            wrap(
                MealListViewController(),
                title: LocalizationKey.Tab.meals.localize,
                systemImage: "fork.knife",
                identifier: "mealsTab"
            ),
            wrap(
                CountryListViewController(),
                title: LocalizationKey.Tab.countries.localize,
                systemImage: "globe",
                identifier: "countriesTab"
            ),
            wrap(
                LaunchListViewController(),
                title: LocalizationKey.Tab.launches.localize,
                systemImage: "airplane",
                identifier: "spaceTab"
            ),
            wrap(
                TestDetayViewController(),
                title: LocalizationKey.Tab.testDetay.localize,
                systemImage: "simcard",
                identifier: "testDetayTab"
            )
        ]
    }

    private func wrap(
        _ root: UIViewController,
        title: String,
        systemImage: String,
        identifier: String
    ) -> UINavigationController {
        root.title = title
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.prefersLargeTitles = true
        root.navigationItem.largeTitleDisplayMode = .always
        nav.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImage),
            selectedImage: UIImage(systemName: systemImage)
        )
        nav.tabBarItem.accessibilityIdentifier = identifier
        return nav
    }

    // MARK: - Floating Button
    private func positionFloatingButtonIfNeeded() {
        guard !didPlaceFloatingButton, view.bounds.width > 0 else { return }
        let safe = view.safeAreaInsets
        let half = AIFloatingButton.size / 2
        let margin = AIFloatingButton.edgeMargin
        let posX = view.bounds.width - safe.right - half - margin
        let posY = view.bounds.height - tabBar.bounds.height - safe.bottom - half - margin
        floatingButton.center = CGPoint(x: posX, y: posY)
        didPlaceFloatingButton = true
    }

    // MARK: - Floating Menu
    private func toggleFloatingMenu() {
        floatingMenu.isHidden ? showFloatingMenu() : hideFloatingMenu()
    }

    private func showFloatingMenu() {
        positionFloatingMenu()
        floatingMenu.isHidden = false
        view.bringSubviewToFront(floatingMenu)
        view.bringSubviewToFront(floatingButton)
        floatingMenu.presentWithAnimation()
    }

    private func hideFloatingMenu(completion: (() -> Void)? = nil) {
        guard !floatingMenu.isHidden else {
            completion?()
            return
        }
        floatingMenu.dismissWithAnimation { [weak self] in
            self?.floatingMenu.isHidden = true
            completion?()
        }
    }

    private func positionFloatingMenu() {
        let menuWidth = AIFloatingMenuView.preferredWidth
        let spacing = AIFloatingMenuView.spacingFromButton
        let safe = view.safeAreaInsets
        let margin = AIFloatingButton.edgeMargin

        // sizeThatFits does not measure Auto Layout content (returns current bounds);
        // systemLayoutSizeFitting computes the stack's actual height.
        let estimatedHeight: CGFloat = 216
        let fitting = floatingMenu.systemLayoutSizeFitting(
            CGSize(width: menuWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let menuHeight = fitting.height > 0 ? fitting.height : estimatedHeight

        let buttonFrame = floatingButton.frame
        let parentBounds = view.bounds

        let preferLeft = buttonFrame.midX > parentBounds.midX
        var originX: CGFloat
        if preferLeft {
            originX = buttonFrame.minX - spacing - menuWidth
            if originX < safe.left + margin {
                originX = buttonFrame.maxX + spacing
            }
        } else {
            originX = buttonFrame.maxX + spacing
            if originX + menuWidth > parentBounds.width - safe.right - margin {
                originX = buttonFrame.minX - spacing - menuWidth
            }
        }
        originX = max(safe.left + margin, min(originX, parentBounds.width - safe.right - margin - menuWidth))

        var originY = buttonFrame.midY - menuHeight / 2
        let minY = safe.top + margin
        let maxY = parentBounds.height - safe.bottom - tabBar.bounds.height - margin - menuHeight
        originY = max(minY, min(originY, maxY))

        floatingMenu.frame = CGRect(x: originX, y: originY, width: menuWidth, height: menuHeight)
    }

    // MARK: - Figma Compare
    private func presentFigmaCompare(provider: FigmaCompareProvider) {
        let identifier = activeScreenIdentifier()
        let viewModel = FigmaCompareViewModel(screenIdentifier: identifier, provider: provider)
        let figmaVC = FigmaCompareViewController(viewModel: viewModel)
        figmaVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissPresented)
        )
        let nav = UINavigationController(rootViewController: figmaVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    /// Returns the type name of the deepest visible VC in the current tab (e.g. "PokemonDetailViewController").
    /// The cloud function uses this identifier to read the related scene files on GitHub.
    private func activeScreenIdentifier() -> String {
        guard let selected = selectedViewController else {
            return String(describing: type(of: self))
        }
        let visible = topmostViewController(from: selected)
        return String(describing: type(of: visible))
    }

    private func topmostViewController(from root: UIViewController) -> UIViewController {
        if let nav = root as? UINavigationController, let top = nav.topViewController {
            return topmostViewController(from: top)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topmostViewController(from: selected)
        }
        if let presented = root.presentedViewController {
            return topmostViewController(from: presented)
        }
        return root
    }

    @objc private func dismissPresented() {
        dismiss(animated: true)
    }

    // MARK: - Chat
    private func presentChat() {
        // Capture the screen the user is looking at BEFORE the analyzer modal opens.
        // The backend uses this to resolve vague bug phrases like "this page/screen".
        let originScreen = String(describing: type(of: topmostViewController(from: self)))
        let chatVC = ViewController()
        chatVC.originScreen = originScreen
        chatVC.title = LocalizationKey.View.AIAssistant.title.localize
        chatVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissChat)
        )
        let nav = UINavigationController(rootViewController: chatVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func dismissChat() {
        dismiss(animated: true)
    }

    // MARK: - Inspector
    private func presentInspector() {
        guard inspectorOverlay == nil else { return }
        let overlay = AIInspectorOverlay.create()
        overlay.delegate = self
        overlay.frame = view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)
        view.bringSubviewToFront(floatingButton)
        inspectorOverlay = overlay
        overlay.presentWithAnimation()
    }

    private func dismissInspector() {
        guard let overlay = inspectorOverlay else { return }
        inspectorOverlay = nil
        overlay.dismissWithAnimation { [weak overlay] in
            overlay?.removeFromSuperview()
        }
    }
}

// MARK: - AIFloatingButtonDelegate
extension MainTabBarController: AIFloatingButtonDelegate {
    func aiFloatingButtonDidTap(_ button: AIFloatingButton) {
        if inspectorOverlay != nil {
            dismissInspector()
            return
        }
        toggleFloatingMenu()
    }
}

// MARK: - AIFloatingMenuViewDelegate
extension MainTabBarController: AIFloatingMenuViewDelegate {
    func aiFloatingMenuViewDidSelectContact(_ view: AIFloatingMenuView) {
        hideFloatingMenu { [weak self] in
            self?.presentChat()
        }
    }

    func aiFloatingMenuViewDidSelectInspect(_ view: AIFloatingMenuView) {
        hideFloatingMenu { [weak self] in
            self?.presentInspector()
        }
    }

    func aiFloatingMenuViewDidSelectFigmaCompare(_ view: AIFloatingMenuView) {
        hideFloatingMenu { [weak self] in
            self?.presentFigmaCompare(provider: .claude)
        }
    }

    func aiFloatingMenuViewDidSelectFigmaCompareGemini(_ view: AIFloatingMenuView) {
        hideFloatingMenu { [weak self] in
            self?.presentFigmaCompare(provider: .gemini)
        }
    }
}

// MARK: - AIInspectorOverlayDelegate
extension MainTabBarController: AIInspectorOverlayDelegate {
    func aiInspectorOverlayDidRequestDismiss(_ overlay: AIInspectorOverlay) {
        dismissInspector()
    }
}
