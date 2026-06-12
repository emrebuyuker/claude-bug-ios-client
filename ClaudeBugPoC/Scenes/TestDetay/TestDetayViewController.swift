//
//  TestDetayViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class TestDetayViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = TestDetayView
    private let viewModel: TestDetayViewModel

    // MARK: - Init
    init(viewModel: TestDetayViewModel = TestDetayViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "testDetayViewController"
        layoutableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

// MARK: - TestDetayViewDelegate
extension TestDetayViewController: TestDetayViewDelegate {
    func testDetayViewDidTapBack() {
        viewModel.didTapBack()
    }

    func testDetayViewDidTapInfo() {
        viewModel.didTapInfo()
    }

    func testDetayView(_ view: TestDetayView, didSelectActionAt index: Int) {
        viewModel.didSelectAction(at: index)
    }
}

// MARK: - TestDetayViewModelDelegate
extension TestDetayViewController: TestDetayViewModelDelegate {
    func testDetayViewModelDidUpdate() {
        layoutableView.configure(plan: viewModel.plan, actions: viewModel.actions)
    }

    func testDetayViewModelDidSelect(action: EsimActionType) {
        // Root VC at tab level — no push target.
        // To be wired up later: install → installation flow, repurchase → purchase, otherPlans → list.
    }

    func testDetayViewModelDidTapBack() {
        navigationController?.popViewController(animated: true)
    }

    func testDetayViewModelDidTapInfo() {
        let alert = UIAlertController(
            title: viewModel.plan.countryTitle,
            message: viewModel.plan.noticeText,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationKey.View.Common.okButton.localize, style: .default))
        present(alert, animated: true)
    }
}
