# ClaudeBugPoC iOS — ViewModel Rules

> **Applies to:** `<Feature>ViewModel.swift` dosyaları.

---

## 1. Temel Prensipler

> **ZORUNLU:** ViewController ↔ ViewModel iletişimi **delegate pattern** ile yapılır. RxSwift, Combine, callback closure (genel state için), KVO **yasak**.

> **ZORUNLU:** ViewModel **UIKit'e import etmez** — `import UIKit` satırı ViewModel dosyasında olamaz. Sadece `Foundation`.

> **ZORUNLU:** ViewModel **navigation tetiklemez** — "git şu ekrana" kararını delegate ile VC'ye iletir, VC `pushViewController` yapar.

> **ZORUNLU:** ViewModel **alert göstermez / present etmez** — hata/uyarı bilgisini delegate ile VC'ye iletir.

---

## 2. Iskelet

```swift
import Foundation

// MARK: - Delegate
protocol HomeViewModelDelegate: AnyObject {
    func homeViewModelDidUpdateItems()
    func homeViewModelDidFailWith(error: Error)
    func homeViewModelDidSelectMovie(_ movie: Movie)
}

// MARK: - ViewModel
final class HomeViewModel {

    // MARK: - Public
    weak var delegate: HomeViewModelDelegate?
    private(set) var items: [Movie] = []
    private(set) var isLoading: Bool = false

    // MARK: - Private
    private var currentPage: Int = 1

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchPopularMovies()
    }

    func viewWillAppear() {
        // refresh varsa burada
    }

    // MARK: - Actions
    func didSelectItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        delegate?.homeViewModelDidSelectMovie(items[index])
    }

    func didPullToRefresh() {
        currentPage = 1
        items = []
        fetchPopularMovies()
    }

    // MARK: - Network
    private func fetchPopularMovies() {
        guard !isLoading else { return }
        isLoading = true

        NetworkManager.shared.request(service: MovieService.popular(page: currentPage)) { [weak self] (result: Result<MovieListResponse, AFError>) in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let response):
                self.items.append(contentsOf: response.results)
                self.delegate?.homeViewModelDidUpdateItems()
            case .failure(let error):
                self.delegate?.homeViewModelDidFailWith(error: error)
            }
        }
    }
}
```

---

## 3. Delegate Protokol Kuralları

### Naming

- Protocol adı: `<Feature>ViewModelDelegate`
- Method adı: `<feature>ViewModelDid<Action>()` — geçmiş zaman + action

```swift
// ✅ DOĞRU
protocol LoginViewModelDelegate: AnyObject {
    func loginViewModelDidStartLoading()
    func loginViewModelDidFinishLoading()
    func loginViewModelDidAuthenticateSuccessfully()
    func loginViewModelDidFailWith(error: Error)
}

// ❌ YANLIŞ — Apple-style "shouldX" / "willX" anonymous form
protocol LoginViewModelDelegate: AnyObject {
    func didLogin()                    // hangi VM?
    func failed(_ error: Error)         // hangi VM?
    func loading(_ isLoading: Bool)    // çok genel
}
```

### `AnyObject` zorunlu

`weak var delegate` kullanılabilmesi için protocol `AnyObject`'e conform etmeli:

```swift
protocol HomeViewModelDelegate: AnyObject { ... }
```

### Default implementation

Opsiyonel delegate method'ları için **extension ile default implementation** yaz, `@objc optional` kullanma (Swift-only project, ObjC interop gereksiz):

```swift
extension HomeViewModelDelegate {
    func homeViewModelDidStartLoading() {}    // default no-op
}
```

---

## 4. State Yönetimi

### `private(set)` kullan

ViewModel state'i **dışarıdan okunur, içeriden yazılır**:

```swift
final class HomeViewModel {
    private(set) var items: [Movie] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?
}
```

VC bunları doğrudan okuyabilir:

```swift
func homeViewModelDidUpdateItems() {
    homeView.configure(with: viewModel.items)
}
```

### Snapshot dön — referans verme

Mutable koleksiyonları (özellikle `Array`, `Dictionary`) **value semantics** ile dön — VC bunları mutate edemesin:

Swift'te `Array` value type olduğu için ekstra defensive copy gerekmiyor. Ama eğer VM içinde `NSMutableArray` ya da reference type bir collection kullanıyorsan **dönmeden önce kopya al**.

---

## 5. Lifecycle Method'ları

ViewModel'in standart lifecycle hooks'u:

| Method | Ne zaman | VC'nin tetiklediği yer |
|--------|---------|------------------------|
| `viewDidLoad()` | İlk yükleme, network fetch | `VC.viewDidLoad()` |
| `viewWillAppear()` | Her ekrana dönüşte refresh | `VC.viewWillAppear(_:)` |
| `viewDidDisappear()` | Cleanup, timer iptal | `VC.viewDidDisappear(_:)` |

UIKit lifecycle'ı doğrudan **override etmiyoruz** — VC'den çağırıyoruz. Bu sayede ViewModel pure Foundation (test edilebilir).

---

## 6. Network Çağrıları

- `NetworkManager.shared.request(service:)` ile yap.
- `[weak self]` zorunlu.
- `guard let self else { return }` yaz (Swift 5.7+ shorthand).
- Hata akışı: switch → `.failure` → `delegate?.didFailWith(error:)`.
- Loading state'i `isLoading` ile expose et + `didStartLoading` / `didFinishLoading` delegate'leri.

> **Detay:** `.claude/rules/networking.md`

---

## 7. Navigation

ViewModel **`navigationController?.pushViewController` çağırmaz**. Bunun yerine:

```swift
// ViewModel
func didTapDetail(at index: Int) {
    guard items.indices.contains(index) else { return }
    delegate?.homeViewModelDidSelectMovie(items[index])
}

// ViewController
func homeViewModelDidSelectMovie(_ movie: Movie) {
    let detailVM = MovieDetailViewModel(movieId: movie.id)
    let detailVC = MovieDetailViewController(viewModel: detailVM)
    navigationController?.pushViewController(detailVC, animated: true)
}
```

**Neden:** ViewModel UIKit'ten bağımsız kalmalı → unit test'lerde Navigation mocklamak zorunda kalmıyoruz.

---

## 8. DI (Dependency Injection)

### Constructor injection

```swift
final class MovieDetailViewModel {
    private let movieId: Int
    private let networkManager: NetworkManager

    init(movieId: Int, networkManager: NetworkManager = .shared) {
        self.movieId = movieId
        self.networkManager = networkManager
    }
}
```

PoC için `NetworkManager.shared` default değer olarak verilebilir. Test'te override edilebilir.

### Service Protokol (ileride)

NetworkManager'ı doğrudan değil, protokol arkasında soyutlamak ileride test edilebilirlik için faydalı:

```swift
protocol NetworkServicing {
    func request<T: Decodable>(service: APIService, completion: @escaping (Result<T, AFError>) -> Void)
}

extension NetworkManager: NetworkServicing {}
```

**Şimdilik over-engineering — gerçek test ihtiyacı doğduğunda ekle.**

---

## 9. Closure & Memory

```swift
// ✅ DOĞRU
NetworkManager.shared.request(service: ...) { [weak self] result in
    guard let self else { return }
    // self.items = ...
}

// ❌ YANLIŞ — retain cycle
NetworkManager.shared.request(service: ...) { result in
    self.items = ...   // strong self
}
```

`Timer.scheduledTimer` ve `NotificationCenter` observer'lar `deinit`'te temizlenmeli.

---

## 10. Test Edilebilirlik

ViewModel test örneği:

```swift
final class HomeViewModelTests: XCTestCase {
    final class Spy: HomeViewModelDelegate {
        var updateCount = 0
        var lastError: Error?
        func homeViewModelDidUpdateItems() { updateCount += 1 }
        func homeViewModelDidFailWith(error: Error) { lastError = error }
        func homeViewModelDidSelectMovie(_ movie: Movie) {}
    }

    func test_viewDidLoad_fetchesMovies() {
        let sut = HomeViewModel()
        let spy = Spy()
        sut.delegate = spy

        sut.viewDidLoad()
        // wait for network — gerçek testte protocol mock'u kullan

        // XCTAssertEqual(spy.updateCount, 1)
    }
}
```

**Test edilebilirlik için ViewModel'i UIKit-free tut.**

---

## 11. ViewModel Checklist

- [ ] `import Foundation` (UIKit yok)
- [ ] `final class`
- [ ] Delegate protokolü `AnyObject` conform
- [ ] `weak var delegate`
- [ ] State property'leri `private(set)`
- [ ] Network çağrılarında `[weak self]` + `guard let self`
- [ ] Navigation/alert/UIKit API çağrısı **yok**
- [ ] Lifecycle method'ları (`viewDidLoad`, `viewWillAppear`) VC tarafından çağrılıyor
- [ ] MARK kurallarına uygun (alt satır boşluksuz)

> **İlgili skill:** `.claude/skills/new-viewcontroller/SKILL.md`, `.claude/skills/new-feature/SKILL.md`
