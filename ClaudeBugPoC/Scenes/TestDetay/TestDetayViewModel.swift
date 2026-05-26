//
//  TestDetayViewModel.swift
//  ClaudeBugPoC
//

import Foundation

// MARK: - Models
struct EsimPlanSummary {
    let countryTitle: String
    let bannerText: String
    let providerName: String
    let badgeText: String
    let dataAmount: String
    let validity: String
    let noticeText: String
}

enum EsimActionType {
    case install
    case repurchase
    case otherPlans
}

struct EsimActionItem {
    let type: EsimActionType
    let title: String
}

// MARK: - Delegate
protocol TestDetayViewModelDelegate: AnyObject {
    func testDetayViewModelDidUpdate()
    func testDetayViewModelDidSelect(action: EsimActionType)
    func testDetayViewModelDidTapBack()
    func testDetayViewModelDidTapInfo()
}

// MARK: - ViewModel
final class TestDetayViewModel {

    // MARK: - Public
    weak var delegate: TestDetayViewModelDelegate?
    private(set) var plan: EsimPlanSummary = .japonyaSample
    private(set) var actions: [EsimActionItem] = EsimActionItem.defaultActions

    // MARK: - Lifecycle
    func viewDidLoad() {
        delegate?.testDetayViewModelDidUpdate()
    }

    // MARK: - Actions
    func didSelectAction(at index: Int) {
        guard actions.indices.contains(index) else { return }
        delegate?.testDetayViewModelDidSelect(action: actions[index].type)
    }

    func didTapBack() {
        delegate?.testDetayViewModelDidTapBack()
    }

    func didTapInfo() {
        delegate?.testDetayViewModelDidTapInfo()
    }
}

// MARK: - Sample Data
private extension EsimPlanSummary {
    static let japonyaSample = EsimPlanSummary(
        countryTitle: "Japonya",
        bannerText: "Bu plan eSIM io'nun Global eSIM'ine dahil değil. Aşağıdaki eSIM'i Kur bağlantısına tıklayarak kurulumu başlatabilirsiniz.",
        providerName: "vodafone",
        badgeText: "Yerel Tarife",
        dataAmount: "1 GB",
        validity: "30 Days",
        noticeText: "Operatör sistemlerinden veri akışı sağlanamadığı için kullanım bilginizi gösteremiyoruz. İnternet bağlantınız bu durumdan bağımsız çalışmaya devam eder."
    )
}

private extension EsimActionItem {
    static let defaultActions: [EsimActionItem] = [
        EsimActionItem(type: .install, title: "eSIM'i Kur"),
        EsimActionItem(type: .repurchase, title: "Tekrar Satın Al"),
        EsimActionItem(type: .otherPlans, title: "Diğer Japonya Planları")
    ]
}
