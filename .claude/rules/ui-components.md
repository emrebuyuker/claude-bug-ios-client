# ClaudeBugPoC iOS — UI Components Rules

> **Applies to:** Tüm `UIView`, `UIViewController`, `UICollectionViewCell`, `UITableViewCell` ve custom UI bileşenleri.

---

## 1. Temel Prensipler

> **ZORUNLU:** Tüm UI **programmatic** — Storyboard / XIB **kesinlikle yasak**.

> **ZORUNLU:** Layout için **sadece SnapKit** — `NSLayoutConstraint`, `translatesAutoresizingMaskIntoConstraints` yasak.

> **ZORUNLU:** Tüm view'lar `LayoutableView`, tüm VC'ler `LayoutingViewController`, tüm collection cell'leri `LayoutableCollectionViewCell` typealias'ına conform eder. Çıplak `UIView` / `UIViewController` / `UICollectionViewCell` subclass'ı yazılmaz.

> **ZORUNLU:** Scrollable / list yapıları için **UICollectionView** (UICollectionViewFlowLayout). Tek karta sahip ekran bile `UIScrollView + contentView` yerine `UICollectionView` ile 1 item dön.

> **İSTİSNA:** Free-form (pinch-zoom canvas, harita, vb.) gerçekten cell pattern'ine uymuyorsa `UIScrollView` kullanılabilir, gerekçe PR'da yazılmalı.

---

## 2. View — `LayoutableView` Pattern

`LayoutableView` = `UIView & Layoutable & Accessible`. Bu typealias bir view'a şunları zorunlu kılar:

1. `func setupViews()` — subview ekleme, `backgroundColor` ataması
2. `func setupLayout()` — SnapKit constraint'leri
3. `generateAccessibilityIdentifiers()` (default impl Accessible'dan gelir) — Mirror ile otomatik `accessibilityIdentifier` ataması

### Iskelet

```swift
//
//  HomeView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class HomeView: LayoutableView {

    // MARK: - UI
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        return cv
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .systemBackground
        addSubview(titleLabel)
        addSubview(collectionView)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
```

**Önemli Detaylar:**
- `override init(frame:)` **yazılmaz** — `Layoutable.create()` factory `Self()` ile inşa eder ve `setupViews()` + `setupLayout()`'u çağırır.
- `setupViews()` ve `setupLayout()` **`func`** olarak yazılır (protocol method'ları), **`private func` değil**.
- `setupViews()` sonunda `generateAccessibilityIdentifiers()` çağrılır.

### Mandatory Rule #1 — `backgroundColor` zorunlu

> **ZORUNLU:** `setupViews()`'in **ilk satırı** her zaman `backgroundColor` ataması olmalı.
>
> - **Tam ekran view:** `backgroundColor = .systemBackground`
> - **Container/cell içindeki view:** `backgroundColor = .clear`

```swift
// ✅ DOĞRU
func setupViews() {
    backgroundColor = .systemBackground
    addSubview(titleLabel)
    generateAccessibilityIdentifiers()
}

// ❌ YANLIŞ — backgroundColor atamayı unuttuk
func setupViews() {
    addSubview(titleLabel)
}
```

### Mandatory Rule #2 — Subview Ownership

> **ZORUNLU:** `setupViews()` **sadece `self`'in doğrudan çocuklarını** ekler. `containerView.addSubview(child)` çağrıları **lazy var declaration'ı içine** taşınır.

```swift
// ❌ YANLIŞ — setupViews içinde alt-konteyner çağrısı
private lazy var containerView = UIView()
private lazy var titleLabel = UILabel()

func setupViews() {
    backgroundColor = .systemBackground
    addSubview(containerView)
    containerView.addSubview(titleLabel)   // ← lazy var'a alınmalı
}

// ✅ DOĞRU — lazy var inşa anında subview'ı ekler
private lazy var titleLabel = UILabel()
private lazy var containerView: UIView = {
    let view = UIView()
    view.backgroundColor = .secondarySystemBackground
    view.layer.cornerRadius = 12
    view.addSubview(titleLabel)
    return view
}()

func setupViews() {
    backgroundColor = .systemBackground
    addSubview(containerView)
    generateAccessibilityIdentifiers()
}
```

### Mandatory Rule #3 — Gesture Ekleme

> **ZORUNLU:** `UITapGestureRecognizer` ve benzeri gesture'lar **ayrı `private lazy var` olarak yazılmaz** — eklenecek view'ın lazy var declaration'ı içinde **local `let`** olarak oluşturulur.

```swift
// ❌ YANLIŞ
private lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
private lazy var avatarView: UIImageView = {
    let iv = UIImageView()
    iv.isUserInteractionEnabled = true
    iv.addGestureRecognizer(tapGesture)
    return iv
}()

// ✅ DOĞRU
private lazy var avatarView: UIImageView = {
    let iv = UIImageView()
    iv.isUserInteractionEnabled = true
    let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
    iv.addGestureRecognizer(tap)
    return iv
}()

@objc private func didTap() { /* ... */ }
```

**İstisna:** Gesture'ı runtime'da `isEnabled = false` ile disable etmek gerekiyorsa `private lazy var` tut.

---

## 3. ViewController — `LayoutingViewController` Pattern

`LayoutingViewController` = `UIViewController & Layouting`. Layouting protokolü `associatedtype ViewType: UIView & Layoutable` ile view tipini bağlar; `layoutableView` computed property'sini sağlar.

### Iskelet

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
    required init?(coder: NSCoder) { fatalError() }

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
```

**Kurallar:**
- `typealias ViewType = <Name>View` zorunlu — Layouting'in associated type'ı.
- `loadView()`'da `super.loadView()` + `view = ViewType.create()` + (opsiyonel) `view.accessibilityIdentifier`.
- View'a erişim `view as! HomeView` ile **DEĞİL** — `layoutableView` ile (Layouting extension'ı sağlıyor):

```swift
func homeViewModelDidUpdateItems() {
    layoutableView.reload()
}
```

---

## 4. Cell — `LayoutableCollectionViewCell` Pattern

`LayoutableCollectionViewCell` = `UICollectionViewCell & Layoutable & Reusable & Accessible`.

### Iskelet

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

**Önemli — Cell ile View arasındaki fark:**

| | LayoutableView | LayoutableCollectionViewCell |
|---|---|---|
| Inşa | `<Name>View.create()` | UIKit `dequeueReusableCell(...)` |
| `init(frame:)` override | ❌ yazma | ✅ yaz (cell'i UIKit init'liyor) |
| `setupViews()` + `setupLayout()` çağırma | `.create()` otomatik çağırır | `init(frame:)` içinde manuel çağır |

### Registration & Dequeue

```swift
// Registration — Reusable.reuseIdentifier default impl'i
collectionView.register(MovieCell.self, forCellWithReuseIdentifier: MovieCell.reuseIdentifier)

// Dequeue
guard let cell = collectionView.dequeueReusableCell(
    withReuseIdentifier: MovieCell.reuseIdentifier,
    for: indexPath
) as? MovieCell else { return UICollectionViewCell() }

cell.configure(with: items[indexPath.item])
return cell
```

**Yasak:** `static let reuseId = "MovieCell"` string literal — bunun yerine `Reusable.reuseIdentifier` default'unu kullan.

### `prepareForReuse`

Image, async state, gesture state varsa override et:

```swift
override func prepareForReuse() {
    super.prepareForReuse()
    titleLabel.text = nil
    posterImageView.image = nil
}
```

---

## 5. Subview olarak Custom View

Cell veya VC içinde reusable bir alt view tanımlanırken **`LayoutableView` typealias'ı** kullanılır (çıplak `UIView` değil):

```swift
final class MovieHeaderView: LayoutableView {

    // MARK: - UI
    private lazy var titleLabel: UILabel = { ... }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .clear   // ← container içinde, parent rengi görünsün
        addSubview(titleLabel)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }

    // MARK: - Public
    func configure(title: String) {
        titleLabel.text = title
    }
}
```

Parent view içinde lazy var olarak `MovieHeaderView.create()` ile inşa edilir:

```swift
private lazy var headerView: MovieHeaderView = {
    let view = MovieHeaderView.create()
    view.configure(title: "Popüler Filmler")
    return view
}()
```

---

## 6. Typography

PoC ölçeğinde **system font** yeterli:

```swift
label.font = .systemFont(ofSize: 16, weight: .regular)
label.font = .systemFont(ofSize: 20, weight: .semibold)
label.font = .systemFont(ofSize: 28, weight: .bold)
```

### Dynamic Type

Önemli text alanlarında destekle:

```swift
label.font = .preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true
```

---

## 7. Colors

**iOS system colors** kullan:

| İhtiyaç | Renk |
|---------|------|
| Ana arka plan | `.systemBackground` |
| İkincil arka plan (card) | `.secondarySystemBackground` |
| Birincil metin | `.label` |
| İkincil metin | `.secondaryLabel` |
| Border / separator | `.separator` |
| Tint | `.tintColor` |
| Hata | `.systemRed` |
| Başarı | `.systemGreen` |

System colors light/dark mode'u otomatik destekler.

---

## 8. Spacing & Sizing

4'ün katları:

| Bağlam | Değer |
|--------|-------|
| Kenar boşluğu (horizontal) | 16pt |
| Section gap | 24pt veya 32pt |
| Inter-item spacing | 12pt |
| Button height | 48pt |
| Cell corner radius | 12pt |

---

## 9. Accessibility

`Accessible` protokolü otomatik identifier üretiyor (DEBUG only):

```swift
func setupViews() {
    // ...
    generateAccessibilityIdentifiers()
}
```

Bu, `lazy var titleLabel`'ı `"HomeView.titleLabel"` olarak identifier'lar — UI test'lerde yararlı.

Manuel atama gerekiyorsa:

```swift
button.accessibilityIdentifier = "loginSubmitButton"
button.accessibilityLabel = "Giriş yap"
```

---

## 10. Alert & Modal Sunumu

```swift
let alert = UIAlertController(title: "Hata", message: "Tekrar deneyin.", preferredStyle: .alert)
alert.addAction(UIAlertAction(title: "Tamam", style: .default))
present(alert, animated: true)
```

Alert sunma **VC'nin sorumluluğu** — ViewModel'den delegate ile tetiklenir.

---

## 11. SafeArea & Keyboard

- Layout her zaman `safeAreaLayoutGuide`'a snap'lensin.
- Klavye davranışı için ileride `IQKeyboardManager` benzeri eklenebilir.

---

## 12. UI Component Checklist (Yeni View Yazarken)

- [ ] `LayoutableView` / `LayoutableCollectionViewCell` typealias'ı kullanıldı
- [ ] `setupViews()` + `setupLayout()` **`func`** olarak yazıldı (private değil)
- [ ] `backgroundColor` `setupViews()`'in ilk satırında atandı
- [ ] `generateAccessibilityIdentifiers()` `setupViews()` sonunda çağrıldı
- [ ] Subview'lar `lazy var` içinde inşa edildi; sadece root child'lar `setupViews()`'de eklendi
- [ ] Gesture'lar lazy var içinde local `let`
- [ ] View için `override init(frame:)` YAZILMADI (cell hariç)
- [ ] Cell için `init(frame:)` override yazıldı + `setupViews/setupLayout` manuel çağrıldı
- [ ] Cell registration `Reusable.reuseIdentifier` kullandı (string literal yok)
- [ ] SnapKit kullanıldı (`NSLayoutConstraint` yok)
- [ ] `safeAreaLayoutGuide`'a snap'lendi
- [ ] System colors kullanıldı (özel renk gereksizse)
- [ ] CollectionView pattern uygulandı (scroll/list varsa)
- [ ] MARK kuralı (alt satır boşluksuz)

> **İlgili skill:** `.claude/skills/new-viewcontroller/SKILL.md`
