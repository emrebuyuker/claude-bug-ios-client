---
name: new-viewcontroller
description: ClaudeBugPoC iOS uygulaması için yeni bir UIViewController + View + ViewModel üçlüsünü Layouting + LayoutableView protokol stack'i ve Delegate pattern ile scaffold eder. Yeni bir ekran/sahne eklerken kullan.
---

> ⚠️ **Protocol Stack Rule (Zorunlu):** VC `LayoutingViewController`, View `LayoutableView`, Cell `LayoutableCollectionViewCell` typealias'larına conform eder. Çıplak `UIView` / `UIViewController` subclass'ı YASAK. Canonical: `.claude/rules/architecture.md`.

> ⚠️ **MARK Rule (Zorunlu):** `// MARK: - <Section>` yorumunun **hemen altında kod** gelmelidir, boş satır olamaz. Canonical: `.claude/rules/architecture.md` (Code Style → MARK).

> ⚠️ **BackgroundColor Rule (Zorunlu):** `setupViews()`'in ilk satırı her zaman `backgroundColor` ataması. Full-screen view → `.systemBackground`; container/cell içinde host edilen view → `.clear`. Canonical: `.claude/rules/ui-components.md`.

> ⚠️ **Subview Ownership Rule (Zorunlu):** `setupViews()` **sadece self'in doğrudan çocuklarını** ekler. Alt-konteyner `addSubview` çağrıları lazy var içine taşınır. Canonical: `.claude/rules/ui-components.md`.

> ⚠️ **Gesture Rule (Zorunlu):** `UITapGestureRecognizer` ayrı `private lazy var` değil — eklenecek view'ın lazy var declaration'ı içinde **local `let`**. Canonical: `.claude/rules/ui-components.md`.

> ⚠️ **No init(frame:) in View (Zorunlu):** `LayoutableView` conform eden view'lar `override init(frame:)` **YAZMAZ** — `Layoutable.create()` factory `Self()` ile inşa eder ve `setupViews`/`setupLayout`'u çağırır. İSTİSNA: `LayoutableCollectionViewCell` — UIKit `dequeue` ile inşa ettiği için `init(frame:)` override yazılır ve `setupViews`/`setupLayout` manuel çağrılır.

# New ViewController + View + ViewModel Scaffold (ClaudeBugPoC)

## Ne zaman kullan

- Kullanıcı yeni bir ekran / scene eklemek istediğinde.
- Push veya present edilecek bağımsız bir VC gerektiğinde.
- Mevcut monolitik `ViewController.swift`'in bir bölümünü ayrı bir scene'e taşırken.

## Akış

1. Ekran adı + amacı netleştir (örn. `MovieList`, `Settings`, `MovieDetail`).
2. Hedef klasörü belirle: `ClaudeBugPoC/Scenes/<ScreenName>/`.
3. **View** dosyasını üret (`<ScreenName>View.swift`) — `LayoutableView` conform.
4. **ViewModel** dosyasını üret (`<ScreenName>ViewModel.swift`).
5. **ViewController** dosyasını üret (`<ScreenName>ViewController.swift`) — `LayoutingViewController` conform.
6. (Gerekirse) Service / Model / Cell üret (Cell → `LayoutableCollectionViewCell`).
7. Navigation entry point'inde TODO veya doğrudan instance push.

## Proje Konvansiyonu

- **Architecture:** ViewController + View + ViewModel (Delegate pattern) + Layouting/Layoutable protokol stack'i
- **UI:** UIKit programmatic — Storyboard / XIB yasak
- **Layout:** SnapKit only
- **Comms:** Delegate (RxSwift / Combine yasak)
- **Networking:** `NetworkManager.shared.request(service:)`
- **Memory:** `[weak self]` closure'larda, `weak var delegate`

## Detaylı Adımlar

### 1. Gereksinimleri topla

Sor ya da çıkar:

- **Ekran adı** (`MovieDetail`, `Login`, `Profile`)
- **Navigation entry point** (hangi VC'den açılıyor, push mu present mi?)
- **Veri ihtiyacı** (hangi API, hangi model)
- **UI tipi** (CollectionView, single card, form, vb.)

```
Screen: <ScreenName>
Purpose: <kısa açıklama>
Entry: <açılış ekranı> tarafından <push|present> ediliyor
Data: <API endpoint veya nil>
UI: <CollectionView | Form | Static cards | ...>
```

### 2. Klasör yapısı

```
ClaudeBugPoC/Scenes/MovieDetail/
├── MovieDetailViewController.swift
├── MovieDetailView.swift
└── MovieDetailViewModel.swift
```

Cell veya alt-view varsa:

```
ClaudeBugPoC/Scenes/MovieDetail/
├── ...
├── Cells/
│   └── CastCollectionViewCell.swift   # LayoutableCollectionViewCell
└── Views/
    └── MovieHeaderView.swift          # LayoutableView
```

### 3. View Şablonu (LayoutableView)

```swift
//
//  MovieDetailView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class MovieDetailView: LayoutableView {

    // MARK: - UI
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var overviewLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, overviewLabel])
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .systemBackground
        addSubview(contentStack)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        contentStack.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualTo(safeAreaLayoutGuide).inset(16)
        }
    }

    // MARK: - Configure
    func configure(title: String, overview: String) {
        titleLabel.text = title
        overviewLabel.text = overview
    }
}
```

**Önemli:**
- `final class ... : LayoutableView` (= `UIView & Layoutable & Accessible`)
- `setupViews()` ve `setupLayout()` **`func`** olarak yazılır (protocol method'ları, `private func` değil)
- `override init(frame:)` **YOK** — `Layoutable.create()` halleder
- `generateAccessibilityIdentifiers()` `setupViews()` sonunda çağrılır

### 4. ViewModel Şablonu

```swift
//
//  MovieDetailViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol MovieDetailViewModelDelegate: AnyObject {
    func movieDetailViewModelDidStartLoading()
    func movieDetailViewModelDidFinishLoading()
    func movieDetailViewModelDidLoadDetail()
    func movieDetailViewModelDidFailWith(error: Error)
}

// MARK: - ViewModel
final class MovieDetailViewModel {

    // MARK: - Public
    weak var delegate: MovieDetailViewModelDelegate?
    private(set) var detail: MovieDetail?

    // MARK: - Private
    private let movieId: Int

    // MARK: - Init
    init(movieId: Int) {
        self.movieId = movieId
    }

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchDetail()
    }

    // MARK: - Network
    private func fetchDetail() {
        delegate?.movieDetailViewModelDidStartLoading()

        NetworkManager.shared.request(service: MovieService.detail(id: movieId)) { [weak self] (result: Result<MovieDetail, AFError>) in
            guard let self else { return }
            self.delegate?.movieDetailViewModelDidFinishLoading()

            switch result {
            case .success(let detail):
                self.detail = detail
                self.delegate?.movieDetailViewModelDidLoadDetail()
            case .failure(let error):
                self.delegate?.movieDetailViewModelDidFailWith(error: error)
            }
        }
    }
}
```

> Detay: `.claude/rules/viewmodelRule.md`

### 5. ViewController Şablonu (LayoutingViewController)

```swift
//
//  MovieDetailViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class MovieDetailViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = MovieDetailView
    private let viewModel: MovieDetailViewModel

    // MARK: - Init
    init(viewModel: MovieDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "movieDetailViewController"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Detail"
        viewModel.delegate = self
        viewModel.viewDidLoad()
    }
}

// MARK: - MovieDetailViewModelDelegate
extension MovieDetailViewController: MovieDetailViewModelDelegate {
    func movieDetailViewModelDidStartLoading() {
        // TODO: show loading spinner
    }

    func movieDetailViewModelDidFinishLoading() {
        // TODO: hide loading spinner
    }

    func movieDetailViewModelDidLoadDetail() {
        guard let detail = viewModel.detail else { return }
        layoutableView.configure(title: detail.title, overview: detail.overview)
    }

    func movieDetailViewModelDidFailWith(error: Error) {
        let alert = UIAlertController(title: "Hata", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }
}
```

**Önemli:**
- `final class ... : LayoutingViewController` (= `UIViewController & Layouting`)
- `typealias ViewType = MovieDetailView` — Layouting'in associated type'ı
- `loadView()`: `super.loadView()` → `view = ViewType.create()` → opsiyonel `view.accessibilityIdentifier`
- View'a erişim: `layoutableView` (Layouting extension'ı sağlıyor), **`view as! MovieDetailView` ASLA**
- `viewModel.delegate = self` `viewDidLoad`'da, `init`'te değil

### 6. Cell Şablonu (LayoutableCollectionViewCell)

```swift
//
//  CastCollectionViewCell.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class CastCollectionViewCell: LayoutableCollectionViewCell {

    // MARK: - UI
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        return label
    }()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layoutable
    func setupViews() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.addSubview(nameLabel)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        nameLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
    }

    // MARK: - Configure
    func configure(name: String) {
        nameLabel.text = name
    }
}
```

**Cell ile View arasındaki fark — kritik:**

| Aşama | LayoutableView | LayoutableCollectionViewCell |
|-------|----------------|------------------------------|
| Inşa noktası | `<Name>View.create()` | UIKit `dequeueReusableCell(...)` |
| `init(frame:)` | **yazma** | **yaz** (override + super + setupViews + setupLayout) |
| `setupViews/Layout` çağrısı | `.create()` otomatik | `init(frame:)` içinde manuel |

**Registration & Dequeue:**

```swift
collectionView.register(CastCollectionViewCell.self, forCellWithReuseIdentifier: CastCollectionViewCell.reuseIdentifier)

guard let cell = collectionView.dequeueReusableCell(
    withReuseIdentifier: CastCollectionViewCell.reuseIdentifier,
    for: indexPath
) as? CastCollectionViewCell else { return UICollectionViewCell() }
```

### 7. Navigation entegrasyonu

Açılış ekranından push:

```swift
// HomeViewController → tap action
let vm = MovieDetailViewModel(movieId: selected.id)
let vc = MovieDetailViewController(viewModel: vm)
navigationController?.pushViewController(vc, animated: true)
```

İlk ekran ise `SceneDelegate`'te:

```swift
let vc = HomeViewController()
let nav = UINavigationController(rootViewController: vc)
window?.rootViewController = nav
```

## Sık Yapılan Hatalar

| Hata | Doğrusu |
|------|--------|
| `final class HomeView: UIView` | `final class HomeView: LayoutableView` |
| `final class HomeViewController: UIViewController` | `final class HomeViewController: LayoutingViewController` + `typealias ViewType = HomeView` |
| `override init(frame:)` View içinde | YAZMA — `.create()` factory halleder |
| Cell'de `init(frame:)` override yok | Cell'de `init(frame:)` zorunlu (UIKit dequeue eder) |
| `view = HomeView()` | `view = ViewType.create()` |
| `private var contentView: HomeView { view as! HomeView }` | `layoutableView` (Layouting extension'ı sağlıyor) |
| `private func setupViews()` | `func setupViews()` (protocol method'u, `private` olamaz) |
| `setupViews()` sonunda accessibility çağrısı eksik | `generateAccessibilityIdentifiers()` ekle |
| `static let reuseId = "MovieCell"` | `MovieCell.reuseIdentifier` (Reusable default) |
| `viewModel.delegate = self` `init`'te | `viewDidLoad`'da yap |
| `MARK` altında boş satır | Direkt declaration başla |
| `present(alert, ...)` ViewModel içinde | Delegate ile VC'ye taşı |
| `UIScrollView + contentView` ile manuel scroll | `UICollectionView` ile 1 item |

## Çıktı Checklist

- [ ] 3 dosya oluşturuldu: VC + View + VM
- [ ] Klasör: `ClaudeBugPoC/Scenes/<ScreenName>/`
- [ ] View `LayoutableView` typealias'ına conform
- [ ] VC `LayoutingViewController` typealias'ına conform, `typealias ViewType = <Name>View`
- [ ] View'da `override init(frame:)` YOK
- [ ] `setupViews()` + `setupLayout()` `func` olarak yazıldı (private değil)
- [ ] `backgroundColor` `setupViews()`'in ilk satırında atandı
- [ ] `generateAccessibilityIdentifiers()` `setupViews()` sonunda çağrıldı
- [ ] VC `loadView()`'da `super.loadView()` + `view = ViewType.create()`
- [ ] VC `viewDidLoad`'da `viewModel.delegate = self` + `viewModel.viewDidLoad()`
- [ ] VC view'a erişimi `layoutableView` ile
- [ ] ViewModel `import Foundation` only (UIKit yok)
- [ ] Delegate protocol `AnyObject` conform, `weak var delegate`
- [ ] `[weak self]` network closure'da
- [ ] `required init?(coder:)` `@available(*, unavailable)`
- [ ] (Varsa) Cell `LayoutableCollectionViewCell` conform + `init(frame:)` override + manual setupViews/Layout
- [ ] (Varsa) Cell registration `Reusable.reuseIdentifier` kullandı
- [ ] Navigation entry point TODO veya entegre

## İlgili Kurallar

- Mimari: `.claude/rules/architecture.md`
- UI: `.claude/rules/ui-components.md`
- ViewModel: `.claude/rules/viewmodelRule.md`
- Networking: `.claude/rules/networking.md`
