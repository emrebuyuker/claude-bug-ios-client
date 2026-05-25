# ClaudeBugPoC iOS — Architecture Rules

> **Applies to:** `ios-client/ClaudeBugPoC/` altındaki tüm Swift dosyaları.

---

## 1. Code Style

### MARK Comments

> **ZORUNLU:** `// MARK: - <Section>` yorumunun **hemen altında** kod gelmelidir — MARK ile bir sonraki declaration arasında boş satır olamaz. MARK'in **üstünde** boş satır olabilir (görsel ayrım için), **altında** olamaz.

```swift
// ❌ YANLIŞ — MARK ile declaration arasında boş satır
final class HomeViewModel {

    // MARK: - Public

    weak var delegate: HomeViewModelDelegate?
}

// ✅ DOĞRU — MARK declaration'a yapışık
final class HomeViewModel {

    // MARK: - Public
    weak var delegate: HomeViewModelDelegate?
}
```

**Neden:** MARK altında boş satır Xcode jump bar'da gereksiz dikey boşluğa neden olur.

### File Header

Her yeni Swift dosyası şu header ile başlar:

```swift
//
//  FileName.swift
//  ClaudeBugPoC
//
```

Author / Date / Copyright satırları **eklenmez** (git zaten tutuyor).

### Naming

| Kategori | Convention | Örnek |
|----------|-----------|-------|
| Type | `PascalCase` | `HomeViewModel`, `MovieDetailView` |
| Function/Variable | `camelCase` | `fetchMovies()`, `selectedMovie` |
| Constant (static) | `camelCase` | `static let baseURL` |
| Enum case | `camelCase` | `case popular(page: Int)` |
| Protocol | `PascalCase` + (uygunsa) suffix | `APIService`, `HomeViewModelDelegate` |

### Access Control

- Default: `internal` (yazmaya gerek yok)
- ViewModel state: `private(set)` (dışarıdan okunur, içeriden yazılır)
- Helper extension'lar: `private` veya `fileprivate`
- Delegate property: `weak var delegate: <Name>Delegate?` (her zaman optional)
- **Protocol method'ları** (`setupViews()`, `setupLayout()`): `internal` (default) — `private` olamaz, protokol gereği görünür kalır

---

## 2. Mimari: ViewController + View + ViewModel (Delegate Pattern)

Bu proje **Layouting + Layoutable protokol stack'i + Delegate-based ViewModel** kullanır.

### Protokol Katmanı

`ClaudeBugPoC/Protocols/` altında **7 dosya**:

| Dosya | Tür | Görev |
|-------|-----|-------|
| `Layoutable.swift` | protocol | `setupViews()` + `setupLayout()` + `create()` factory |
| `Layouting.swift` | protocol | `associatedtype ViewType` + `layoutableView` computed prop |
| `Accessible.swift` | protocol | Mirror ile otomatik `accessibilityIdentifier` üretimi (DEBUG) |
| `Reusable.swift` | protocol | Default `reuseIdentifier = String(describing: type(of: self))` |
| `LayoutableView.swift` | typealias | `UIView & Layoutable & Accessible` |
| `LayoutingViewController.swift` | typealias | `UIViewController & Layouting` |
| `LayoutableCollectionViewCell.swift` | typealias | `UICollectionViewCell & Layoutable & Reusable & Accessible` |

> **ZORUNLU:** Her yeni `UIView` `LayoutableView`'a, her yeni `UIViewController` `LayoutingViewController`'a, her yeni `UICollectionViewCell` `LayoutableCollectionViewCell`'e conform eder. Çıplak `UIView` / `UIViewController` / `UICollectionViewCell` subclass'ı yazılmaz.

### Katman Sorumlulukları

| Katman | Sorumluluk | Base |
|--------|-----------|------|
| **ViewController** | UI koordinasyonu, delegate yönetimi | `LayoutingViewController` + `typealias ViewType = <Name>View` |
| **View** | UI rendering, layout (SnapKit) | `LayoutableView` — `setupViews()` + `setupLayout()` |
| **ViewModel** | Business logic, state, network calls | Delegate protocol |
| **Cell** | Cell rendering | `LayoutableCollectionViewCell` |
| **Service** | API endpoint tanımı | `APIService` enum |
| **NetworkManager** | HTTP dispatch | `static let shared` |

### Modül (Scene) Klasör Yapısı

```
ClaudeBugPoC/Scenes/<FeatureName>/
├── <FeatureName>ViewController.swift   # LayoutingViewController
├── <FeatureName>View.swift             # LayoutableView
├── <FeatureName>ViewModel.swift        # State + business logic
├── Cells/                              # opsiyonel
│   └── <FeatureName>CollectionViewCell.swift   # LayoutableCollectionViewCell
└── Views/                              # opsiyonel — alt view'lar (LayoutableView)
    └── <FeatureName>HeaderView.swift
```

Destek dosyaları:

```
ClaudeBugPoC/Networking/Services/
└── <FeatureName>Service.swift          # APIService enum

ClaudeBugPoC/Networking/Models/
├── <FeatureName>Request.swift          # request body (varsa)
└── <FeatureName>Response.swift         # decode'lanan model
```

### Yasak Patternler

- ❌ **SwiftUI** — proje UIKit-only
- ❌ **Storyboard / XIB**
- ❌ **RxSwift / Combine** — delegate pattern
- ❌ **Coordinator pattern**
- ❌ **Repository pattern**
- ❌ **URLSession** doğrudan — sadece `NetworkManager.shared.request(service:)`
- ❌ **Çıplak `UIView` / `UIViewController` / `UICollectionViewCell` subclass'ı** — protokol typealias'larını kullan
- ❌ **`override init(frame:)` View içinde** — `.create()` factory kullan (Layoutable extension'ı zaten halleder)

### Zorunlu Patternler

- ✅ UIKit + SnapKit
- ✅ Delegate pattern (VC ↔ VM iletişimi)
- ✅ `LayoutingViewController` + `typealias ViewType`
- ✅ `LayoutableView` + `setupViews()` + `setupLayout()`
- ✅ `LayoutableCollectionViewCell` + `Reusable.reuseIdentifier`
- ✅ `NetworkManager.shared.request(service:)`
- ✅ `[weak self]` closure'larda; `weak var` delegate'lerde

---

## 3. ViewController Iskeleti

```swift
//
//  HomeViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class HomeViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = HomeView
    private let viewModel: HomeViewModel

    // MARK: - Init
    init(viewModel: HomeViewModel = HomeViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "homeViewController"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        viewModel.viewDidLoad()
    }
}

// MARK: - HomeViewModelDelegate
extension HomeViewController: HomeViewModelDelegate {
    func homeViewModelDidUpdateItems() {
        layoutableView.reload()
    }

    func homeViewModelDidFailWith(error: Error) {
        let alert = UIAlertController(title: "Hata", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }
}
```

**Önemli kurallar:**
- `LayoutingViewController` typealias'ına conform et (= `UIViewController & Layouting`).
- `typealias ViewType = <Name>View` ile associated type'ı bağla.
- `loadView()` içinde `view = ViewType.create()` çağır (`create()` Layoutable extension'ından gelir, `setupViews` + `setupLayout`'u çağırır).
- View'a `view as! HomeView` ile değil **`layoutableView`** ile eriş (Layouting extension'ından gelir).
- `viewModel.delegate = self` `viewDidLoad`'da set edilir, `init`'te değil.

---

## 4. View Iskeleti

```swift
//
//  HomeView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class HomeView: LayoutableView {

    // MARK: - UI
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(MovieCell.self, forCellWithReuseIdentifier: MovieCell.reuseIdentifier)
        return cv
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .systemBackground
        addSubview(collectionView)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
    }

    // MARK: - Public
    func reload() {
        collectionView.reloadData()
    }
}
```

**Önemli kurallar:**
- `LayoutableView` typealias'ı (= `UIView & Layoutable & Accessible`).
- `setupViews()` + `setupLayout()` **protocol method'ları** → `func` olarak yaz, `private func` değil.
- **`override init(frame:)` YAZMA** — `.create()` factory zaten halleder; gereksiz init compile etmez (Layoutable.create() `Self()` çağırır).
- `setupViews()`'in **ilk satırında** `backgroundColor` ataması (full-screen → `.systemBackground`, container içi → `.clear`).
- `setupViews()` sonunda `generateAccessibilityIdentifiers()` çağrısı (Accessible protokolünden, DEBUG'da otomatik identifier üretir).
- Subview'lar **lazy var** içinde inşa edilir; sadece root child'lar `setupViews()`'de `addSubview` edilir.

> Detay: `.claude/rules/ui-components.md`

---

## 5. ViewModel Iskeleti

```swift
//
//  HomeViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol HomeViewModelDelegate: AnyObject {
    func homeViewModelDidUpdateItems()
    func homeViewModelDidFailWith(error: Error)
}

// MARK: - ViewModel
final class HomeViewModel {

    // MARK: - Public
    weak var delegate: HomeViewModelDelegate?
    private(set) var items: [Movie] = []

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchPopularMovies()
    }

    // MARK: - Network
    private func fetchPopularMovies() {
        NetworkManager.shared.request(service: MovieService.popular(page: 1)) { [weak self] (result: Result<MovieListResponse, AFError>) in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.items = response.results
                self.delegate?.homeViewModelDidUpdateItems()
            case .failure(let error):
                self.delegate?.homeViewModelDidFailWith(error: error)
            }
        }
    }
}
```

> Detay: `.claude/rules/viewmodelRule.md`

---

## 6. Cell Iskeleti

```swift
//
//  MovieCell.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class MovieCell: LayoutableCollectionViewCell {

    // MARK: - UI
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    // MARK: - Layoutable
    func setupViews() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.addSubview(titleLabel)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
    }

    // MARK: - Configure
    func configure(with movie: Movie) {
        titleLabel.text = movie.title
    }
}
```

**Cell registration & dequeue:**

```swift
// Registration
collectionView.register(MovieCell.self, forCellWithReuseIdentifier: MovieCell.reuseIdentifier)

// Dequeue
let cell = collectionView.dequeueReusableCell(
    withReuseIdentifier: MovieCell.reuseIdentifier,
    for: indexPath
) as? MovieCell
```

Cell `LayoutableCollectionViewCell` typealias'ı sayesinde:
- `setupViews()` / `setupLayout()` zorunlu (Layoutable),
- `reuseIdentifier` default `"MovieCell"` döner (Reusable),
- `generateAccessibilityIdentifiers()` mevcut (Accessible).

**Önemli:** Cell oluştururken `.create()` çağrılmaz — UIKit cell instance'ını kendi yönetir (registration üzerinden). Cell `setupViews` + `setupLayout` çağrılarını `init(frame:)` içinde **manuel olarak** yapmalı:

```swift
override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
    setupLayout()
}

@available(*, unavailable)
required init?(coder: NSCoder) { fatalError() }
```

> **Neden cell'de manual init?** UICollectionView'lar cell'i `dequeueReusableCell(...)` ile üretir — `.create()` çağrılma şansı yok. Bu yüzden `init(frame:)` override edilir.

---

## 7. Dependency Injection

- **Constructor injection** kullan.
- ViewModel'in default değeri olabilir:

```swift
init(viewModel: HomeViewModel = HomeViewModel()) { ... }
```

- NetworkManager doğrudan VM içinde `.shared` ile kullanılabilir; protokol-tabanlı abstraction ileride test ihtiyacı doğunca eklenir.

---

## 8. Memory Management

| Yer | Kural |
|-----|-------|
| Closure'da `self` | `[weak self] in` + `guard let self else { return }` |
| Delegate property | `weak var delegate: ...?` |
| NotificationCenter observer | `removeObserver` `deinit`'te veya `viewWillDisappear`'da |
| Timer | `invalidate()` + `nil` `deinit`'te |

---

## 9. Error Handling

- Network hataları: `Result<T, AFError>` → ViewModel'de switch → delegate ile VC'ye ilet.
- VC: kullanıcıya `UIAlertController` veya inline error view göster.
- `try!` ve `fatalError` sadece **programlama hatası** için (örn. `required init?(coder:)` unavailable, `layoutableView` cast hatası).
- `try?` ile sessizce yutma — `#if DEBUG print(...)` ile log'la.

---

## 10. Logging

`#if DEBUG print(...)` yeterli. Production log'a **asla** kullanıcı verisi yazma.

---

## 11. Dosya Uzunluğu Limitleri

| Dosya türü | Soft limit |
|-----------|-----------|
| ViewController | 200 satır |
| View | 400 satır |
| ViewModel | 300 satır |
| Tek fonksiyon | 50 satır |

---

## 12. iOS Deployment Target

- **iOS 15.0+** (Podfile sabit)
- `@available(iOS 16, *)` API kullanırken **fallback yaz**.
- `async/await` rahatça kullanılabilir.

---

## 13. Üçüncü Parti Kütüphaneler

| Kütüphane | Kullanım | Yasak alternatif |
|-----------|----------|------------------|
| Alamofire | HTTP | URLSession (NetworkManager dışında) |
| SnapKit | Layout | NSLayoutConstraint, autoresizing masks |
| FirebaseFunctions | Backend | Custom HTTP for Firebase |
| FirebaseAppCheck | App integrity | — |

---

## 14. Git & Branch

- Branch: `feature/<name>` / `fix/<name>` / `chore/<name>`
- Commit: imperative, kısa — `Add HomeViewModel`, `Fix detail crash`
- `.gitignore`'da: `.DS_Store`, `Pods/`, `xcuserdata`, `GoogleService-Info.plist`

---

## 15. Refactor Notu — Mevcut `ViewController.swift`

`ClaudeBugPoC/ViewController.swift` tek monolitik dosya (chat UI + diff renderer + Firebase çağrıları). Bu dosya yeni feature **örneği değildir**; bu pattern'i kopyalama, üstteki `LayoutingViewController` + `LayoutableView` iskeletini kullan. Mevcut dosya kademeli olarak `Scenes/Chat/` altına parçalanacak.
