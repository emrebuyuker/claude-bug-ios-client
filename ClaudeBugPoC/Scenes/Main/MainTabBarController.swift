//
//  MainTabBarController.swift
//  ClaudeBugPoC
//

import UIKit

final class MainTabBarController: UITabBarController {

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        viewControllers = makeTabs()
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
                title: "Pokémon",
                systemImage: "circle.hexagongrid.fill",
                identifier: "pokemonTab"
            ),
            wrap(
                MealListViewController(),
                title: "Tarifler",
                systemImage: "fork.knife",
                identifier: "mealsTab"
            ),
            wrap(
                CountryListViewController(),
                title: "Ülkeler",
                systemImage: "globe",
                identifier: "countriesTab"
            ),
            wrap(
                LaunchListViewController(),
                title: "Uzay",
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
}
