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

    private var didPlaceFloatingButton = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        viewControllers = makeTabs()
        view.addSubview(floatingButton)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionFloatingButtonIfNeeded()
        view.bringSubviewToFront(floatingButton)
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

    @objc private func dismissChat() {
        dismiss(animated: true)
    }
}

// MARK: - AIFloatingButtonDelegate
extension MainTabBarController: AIFloatingButtonDelegate {
    func aiFloatingButtonDidTap(_ button: AIFloatingButton) {
        let chatVC = ViewController()
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
}
