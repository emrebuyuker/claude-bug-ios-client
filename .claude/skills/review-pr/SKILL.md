---
name: review-pr
description: ClaudeBugPoC iOS pull request'leri için kapsamlı bir review checklist çalıştırır. Mimari, networking, UI, ViewModel ve güvenlik kurallarına uyumu kontrol eder. Bir PR'ı review ederken veya merge öncesi self-check yaparken kullan.
---

> ⚠️ Bu skill, **`.claude/rules/`** altındaki tüm rule dosyalarındaki "Mandatory" kuralları somut bir checklist'e çevirir. Review sırasında her madde için **kanıtla** (dosya:satır referansı) bulgu ya da onay üret.

# PR Review Checklist (ClaudeBugPoC)

## Ne zaman kullan

- Bir PR'ı review ediyoruz.
- Kendi branch'ini merge etmeden önce self-check yapıyoruz.
- Mevcut bir feature refactor'unu kontrol ediyoruz.

## Akış

1. PR'ı git veya gh ile aç, değişen dosyaları listele.
2. Her dosyayı, bu skill'deki uygun kategoriye göre kontrol et.
3. Her bulgu için **dosya:satır + ihlal edilen kural + önerilen düzeltme**.
4. Sonuç: kabul / değişiklik talep / blocker olarak özetle.

## Komutlar

```bash
# Mevcut branch ile main arasındaki diff
git diff main...HEAD --stat
git diff main...HEAD

# Değişen Swift dosyaları
git diff main...HEAD --name-only --diff-filter=AM | grep '\.swift$'
```

## 1. Mimari (architecture.md)

- [ ] **MARK kuralı:** `// MARK: - X` altında **boş satır yok**. Üstünde boşluk olabilir.
- [ ] **File header:** `//  <FileName>.swift\n//  ClaudeBugPoC\n//` formatı. Author/Date/Copyright satırı **yok**.
- [ ] **Protocol stack typealias'ları kullanılmış:** `LayoutableView`, `LayoutingViewController`, `LayoutableCollectionViewCell`. Çıplak UIKit subclass'ı YOK.
- [ ] **Yasak importlar:** ViewModel'de `import UIKit` **yok**. SwiftUI proje genelinde **yok**.
- [ ] **Yasak frameworks:** RxSwift, Combine, ReactiveSwift import edilmemiş.
- [ ] **Folder yapısı:** Yeni ekranlar `Scenes/<Feature>/` altında, networking `Networking/` altında, protokoller `Protocols/` altında.
- [ ] **Singleton patlaması yok:** Yeni `static let shared` eklenmişse gerçek bir state ihtiyacı var mı?
- [ ] **Dosya uzunluğu:** VC < 200 satır, View < 400, VM < 300 (soft limit — aşıldıysa gerekçesi yorumlanmış olmalı).
- [ ] **iOS 15+ uyumlu:** `@available(iOS 16, *)` API kullanılmışsa fallback var.

## 2. ViewController (architecture.md + new-viewcontroller)

- [ ] **`final class ... : LayoutingViewController`** — çıplak `UIViewController` subclass'ı YOK.
- [ ] **`typealias ViewType = <Name>View`** sınıf içinde tanımlanmış.
- [ ] **`loadView()` override:** `super.loadView()` → `view = ViewType.create()` (opsiyonel: `view.accessibilityIdentifier`).
- [ ] **View'a erişim `layoutableView` üzerinden** — `view as! <Name>View` cast'i veya custom `contentView` property'si YOK.
- [ ] **`viewModel.delegate = self` `viewDidLoad`'da set ediliyor**, `init`'te değil.
- [ ] **`viewModel.viewDidLoad()` `super.viewDidLoad()`'tan sonra çağrılıyor.**
- [ ] **Constructor injection:** `init(viewModel: <Name>ViewModel)` — VM içeride yaratılmıyor (default değer OK).
- [ ] **`required init?(coder:)` `@available(*, unavailable)` ile işaretli + `fatalError`.**
- [ ] **Delegate handler'ları extension'da** `// MARK: - <Delegate>` altında.
- [ ] **Alert / present çağrıları yalnızca VC'de.**

## 3. View (ui-components.md)

- [ ] **`final class ... : LayoutableView`** — çıplak `UIView` subclass'ı YOK.
- [ ] **`override init(frame:)` View içinde YAZILMAMIŞ** — `Layoutable.create()` factory inşa ediyor. (Cell istisnası: cell'de zorunlu.)
- [ ] **`setupViews()` + `setupLayout()` `func` olarak** yazılmış — `private func` değil (protocol method'u).
- [ ] **`setupViews()` ilk satırında `backgroundColor`** atanmış (full-screen → `.systemBackground`, container içi → `.clear`).
- [ ] **`setupViews()` sonunda `generateAccessibilityIdentifiers()`** çağrılmış.
- [ ] **Subview ownership:** `setupViews()` **sadece self'in doğrudan çocuklarını** ekliyor; alt-konteyner `addSubview`'leri lazy var içinde.
- [ ] **Gesture rule:** `UITapGestureRecognizer` ayrı `private lazy var` değil — view'ın lazy var body'sinde local `let`.
- [ ] **SnapKit:** `NSLayoutConstraint` / `translatesAutoresizingMaskIntoConstraints` yok.
- [ ] **Storyboard / XIB referansı yok.**
- [ ] **CollectionView pattern:** Scroll/list varsa `UIScrollView + contentView` değil `UICollectionView`.
- [ ] **`safeAreaLayoutGuide`'a snap** (gerektiği yerde).
- [ ] **Cell'lerde `final class ... : LayoutableCollectionViewCell`** — çıplak `UICollectionViewCell` subclass'ı YOK.
- [ ] **Cell'de `init(frame:)` override + manuel `setupViews()` + `setupLayout()` çağrısı** mevcut.
- [ ] **Cell registration / dequeue `<Cell>.reuseIdentifier`** (Reusable default) — string literal YOK.
- [ ] **Cell `contentView` üzerine ekleniyor**, `self` üzerine değil.

## 4. ViewModel (viewmodelRule.md)

- [ ] **`import Foundation` only** — UIKit yok.
- [ ] **`final class`.**
- [ ] **Delegate protocol `AnyObject`'e conform.**
- [ ] **`weak var delegate: <Name>ViewModelDelegate?`.**
- [ ] **State `private(set)`** — dışarıdan mutate edilemez.
- [ ] **Delegate method adlandırma:** `<vm>ViewModelDid<Action>()` — geçmiş zaman + action.
- [ ] **Network closure'da `[weak self]` + `guard let self else { return }`.**
- [ ] **Navigation tetiklenmiyor** — `navigationController?.push` veya `present` yok.
- [ ] **Alert göstermiyor** — hata bilgisi delegate ile VC'ye iletiliyor.
- [ ] **Lifecycle method'ları (`viewDidLoad`, `viewWillAppear`) VC tarafından çağrılıyor**, UIKit override yok.

## 5. Networking (networking.md)

- [ ] **`NetworkManager.shared.request(service:)` kullanılıyor.** `URLSession`, custom `Session` yok.
- [ ] **Magic URL yok** — her endpoint Service enum case'i.
- [ ] **Response `Decodable` struct** — `[String: Any]` JSONSerialization yok.
- [ ] **`CodingKeys` snake_case → camelCase** mapping yapılmış.
- [ ] **Service enum tek extension'da** — property'ler ayrı extension'lara dağılmamış.
- [ ] **Switch'ler exhaustive** — `default` case yok.
- [ ] **Headers `ApiConstant.getHeaders()` üzerinden.**
- [ ] **401 / hata akışı** delegate ile iletildi.
- [ ] **Generic tip explicit:** `(Result<MovieListResponse, AFError>)`.
- [ ] **Sensitive veri log'lanmıyor:** Token / e-mail / kart no `print`'lerde yok.

## 6. Memory & Concurrency

- [ ] **Closure'larda `[weak self]`** — retain cycle yok.
- [ ] **Timer/Observer cleanup** `deinit`'te.
- [ ] **`Task { [weak self] in ... }`** async closure'larda da weak.
- [ ] **`@MainActor`** UI update yapan async fonksiyonlarda işaretli (kullanılıyorsa).

## 7. Güvenlik

- [ ] **Token / API key hard-code edilmemiş.** `GoogleService-Info.plist` veya `.env` benzeri config'ten okunuyor.
- [ ] **`GoogleService-Info.plist` `.gitignore`'da** — örnek `.example` dosyası repo'da, gerçek dosya değil.
- [ ] **Keychain / UserDefaults:** Sensitive veri (refresh token) için UserDefaults kullanılıyorsa TODO ile işaretlenmiş.
- [ ] **AppCheck provider'ı `AppDelegate`'te set ediliyor.**
- [ ] **Debug-only kod `#if DEBUG` ile sarılmış** — `print`, debug provider, vb.

## 8. Test

- [ ] **(Eğer test eklendiyse)** unit test ViewModel'i UIKit-free şekilde test ediyor.
- [ ] **Spy / mock pattern** kullanılmış — gerçek network çağrısı test'te yok.

## 9. Genel Hijyen

- [ ] **`// TODO:` / `// FIXME:`** açıklamalı (boş "TODO" yok).
- [ ] **Yorumlar gerçek "neden"i açıklıyor** — kod ne yapıyor diye anlatan yorum yok.
- [ ] **Commit mesajları** imperative + kısa.
- [ ] **Pods/ değişikliği yok** — `Podfile.lock` değişti ama `Pods/` repo'da değil (`.gitignore`'a göre).
- [ ] **`.DS_Store`** commit'lenmemiş.
- [ ] **xcuserdata / xcuserstate** commit'lenmemiş.
- [ ] **Kullanılmayan import yok.**
- [ ] **Ölü kod yok** — commented-out blok'lar temizlenmiş.

## 10. PR Description / Süreç

- [ ] **PR title < 70 karakter, imperative.**
- [ ] **Body'de:** Summary + Test plan + (opsiyonel) Screenshot.
- [ ] **Tek bir konu** — refactor + feature + bugfix karışmamış.

## Rapor Formatı

Review sonucunu şu şekilde özetle:

```
## Review: <PR title>

### ✅ İyi giden
- ...

### ⚠️ Önerilen değişiklikler (blocker değil)
- <dosya>:<satır> — <kural> — <öneri>

### ❌ Blocker
- <dosya>:<satır> — <kural> — <gerekçe>

### Sonuç: Approve | Request Changes | Block
```

## İlgili Kurallar

- `.claude/rules/architecture.md`
- `.claude/rules/networking.md`
- `.claude/rules/ui-components.md`
- `.claude/rules/viewmodelRule.md`
