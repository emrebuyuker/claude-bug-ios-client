# ClaudeBugPoC iOS

Claude tabanlı kod öneri / proposed change iOS PoC uygulaması.

> **Not:** Proje kurallarının tamamı `.claude/rules/` altında, kod üretim şablonları ise `.claude/skills/` altında tanımlıdır. Bu dosya Claude'a özel ek bilgileri içerir.

---

## ⚠️ Claude İçin Kritik Talimat

**HER İSTEK ÖNCESİ ZORUNLU ADIMLAR:**

1. **İlk olarak `.claude/` klasörünün tamamını tara**
2. **Tüm `.md` dosyalarını oku ve içeriklerini analiz et**
3. **İlgili SKILL dosyalarını belirle**
4. **Ancak bundan sonra işleme başla**

```bash
# Önce şu komutu çalıştır:
find .claude -name "*.md" | head -20

# Ardından ilgili dosyaları oku:
cat .claude/skills/<skill-klasoru>/SKILL.md
cat .claude/rules/<rule-dosyasi>.md
```

**Neden Bu Gerekli?**
- Her istek için güncel mimari kurallar `.claude/rules/` içinde
- Skill dosyaları kod üretimi için şablonları içerir
- Eski (monolitik `ViewController.swift`) pattern'i yeni dosyalara taşıma — **bu dosyayı örnek almaks**
- Proje standartları sürekli güncelleniyor

**İşlem Sırası:**
1. 🔍 `.claude/skills/` ve `.claude/rules/` tarama
2. 📖 İlgili SKILL + rule dosyalarını okuma
3. ✅ Kuralları doğrulama
4. ⚡ İşlemi gerçekleştirme

---

## Hızlı Referans

| Özellik | Değer |
|---------|-------|
| **Platform** | iOS 15.0+ |
| **Dil** | Swift (UIKit, NO SwiftUI) |
| **Mimari** | ViewController + View + ViewModel (Delegate Pattern) + Layouting/Layoutable protokol stack'i |
| **UI** | UIKit programmatic — NO Storyboards/XIBs |
| **Layout** | SnapKit |
| **Protokol Stack** | `LayoutableView`, `LayoutingViewController`, `LayoutableCollectionViewCell` (zorunlu typealias'lar) |
| **Networking** | Alamofire + `APIService` enum + `NetworkManager.shared` |
| **Backend** | Firebase Functions + AppCheck |
| **DI** | Constructor Injection |
| **Reactive** | ❌ NO RxSwift, NO Combine (Delegate Pattern) |
| **Package Manager** | CocoaPods |

---

## Proje Yapısı (Hedef)

```
ClaudeBugPoC/
├── AppDelegate.swift
├── SceneDelegate.swift
├── Info.plist
├── GoogleService-Info.plist           # gitignored, .example versiyonu var
├── Assets.xcassets/
├── Protocols/                         # ⚙️ Layouting/Layoutable protokol stack'i
│   ├── Layoutable.swift               # setupViews + setupLayout + .create()
│   ├── Layouting.swift                # associatedtype ViewType + layoutableView
│   ├── Accessible.swift               # Mirror-based accessibilityIdentifier
│   ├── Reusable.swift                 # static reuseIdentifier
│   ├── LayoutableView.swift           # typealias UIView & Layoutable & Accessible
│   ├── LayoutingViewController.swift  # typealias UIViewController & Layouting
│   └── LayoutableCollectionViewCell.swift   # typealias UICollectionViewCell & Layoutable & Reusable & Accessible
├── Scenes/                            # Feature modülleri — her sahne kendi klasöründe
│   └── <ScreenName>/
│       ├── <ScreenName>ViewController.swift   # LayoutingViewController
│       ├── <ScreenName>View.swift             # LayoutableView
│       ├── <ScreenName>ViewModel.swift
│       ├── Cells/                     # opsiyonel — LayoutableCollectionViewCell
│       └── Views/                     # opsiyonel — LayoutableView alt-view'lar
├── Networking/
│   ├── APIService.swift               # Protocol
│   ├── NetworkManager.swift           # Singleton dispatcher
│   ├── Constants/
│   │   ├── ApiConstant.swift
│   │   └── ApiError.swift
│   ├── Helpers/
│   │   ├── ApiRequestHelper.swift
│   │   └── ApiResponseHelper.swift
│   ├── Models/                        # Decodable model'ler
│   │   └── <Feature>Response.swift
│   └── Services/                      # APIService enum'ları
│       └── <Feature>Service.swift
├── Managers/                          # Singleton manager'lar (auth, session)
│   └── <Feature>Manager.swift
├── Common/                            # Reusable view'lar, helper'lar
└── Extensions/                        # UIKit / Foundation extension'lar

.claude/                               # ⚠️ Claude AI konfigürasyonu
├── rules/                             # Proje kuralları
│   ├── architecture.md                # Genel mimari + code style
│   ├── networking.md                  # API / NetworkManager kuralları
│   ├── ui-components.md               # View / Cell / Layout kuralları
│   └── viewmodelRule.md               # ViewModel + delegate kuralları
└── skills/                            # Kod üretim şablonları
    ├── new-viewcontroller/SKILL.md    # Yeni ekran (VC + View + VM)
    ├── new-feature/SKILL.md           # Tam feature modülü
    ├── networking-service/SKILL.md    # Yeni APIService enum / case
    └── review-pr/SKILL.md             # PR review checklist
```

> **Şu an mevcut durum:** Tek monolitik `ClaudeBugPoC/ViewController.swift` dosyası (chat + diff UI + Firebase çağrıları). Yeni feature'lar **bu dosyayı örnek almadan** yukarıdaki yapıya göre eklenmeli. Mevcut dosya kademeli olarak parçalanacak.

---

## Temel Kurallar

- **ViewController**: `LayoutingViewController` typealias'ı + `typealias ViewType = <Name>View`. `loadView()`'da `super.loadView()` + `view = ViewType.create()`. View'a erişim **`layoutableView`** ile (Layouting extension'ı). `viewDidLoad`'da `viewModel.delegate = self`.
- **View**: `LayoutableView` typealias'ı. `setupViews()` + `setupLayout()` **`func`** olarak (protocol method'u, `private` değil). İlk satırda `backgroundColor`, sonda `generateAccessibilityIdentifiers()`. **`override init(frame:)` YOK** — `Layoutable.create()` factory halleder.
- **Cell**: `LayoutableCollectionViewCell` typealias'ı. `init(frame:)` override **gerekli** + manuel `setupViews()` + `setupLayout()` çağrısı (UIKit cell'i dequeue ediyor). Registration/dequeue `<Cell>.reuseIdentifier` (Reusable default).
- **ViewModel**: `import Foundation` only (UIKit yok), delegate pattern (`AnyObject`), `weak var delegate`, state `private(set)`.
- **Navigation**: VC seviyesinde `navigationController?.pushViewController`. **ViewModel navigation tetiklemez.**
- **Networking**: `NetworkManager.shared.request(service:)` ile `APIService` enum case'i. `URLSession` doğrudan yasak.
- **Layout**: Sadece SnapKit. `NSLayoutConstraint`, `translatesAutoresizingMaskIntoConstraints` yasak.
- **Storyboard / XIB / SwiftUI**: ❌ Yasak — tüm UI programmatic UIKit.
- **RxSwift / Combine**: ❌ Yasak — delegate pattern kullan.
- **MARK**: `// MARK: - X` altında **boş satır yok**, üstünde boşluk OK.
- **Memory**: `[weak self]` closure'larda, `weak var` delegate'lerde.

---

## SKILL Dosyaları — Tam Liste

| Dosya | Konum | Konu |
|-------|-------|------|
| `SKILL.md` | `.claude/skills/new-viewcontroller/` | Yeni ekran (VC + View + ViewModel) scaffold |
| `SKILL.md` | `.claude/skills/new-feature/` | Tam feature modülü (1+ ekran + Service + Models) |
| `SKILL.md` | `.claude/skills/networking-service/` | Yeni APIService enum / endpoint case |
| `SKILL.md` | `.claude/skills/review-pr/` | PR review checklist |

---

## RULE Dosyaları — Tam Liste

| Dosya | Konum | Konu |
|-------|-------|------|
| `architecture.md` | `.claude/rules/` | Genel mimari + code style + folder yapısı |
| `networking.md` | `.claude/rules/` | NetworkManager, APIService, Service enum, error handling |
| `ui-components.md` | `.claude/rules/` | UIView/UIViewController/Cell/Layout — Mandatory rule'lar |
| `viewmodelRule.md` | `.claude/rules/` | ViewModel pattern, delegate, lifecycle, DI |

---

## Skill ↔ Task Eşleştirmesi

| Task | SKILL Dosyası |
|------|--------------|
| Yeni ekran oluştur | `.claude/skills/new-viewcontroller/SKILL.md` |
| Yeni feature oluştur | `.claude/skills/new-feature/SKILL.md` |
| Yeni endpoint / Service ekle | `.claude/skills/networking-service/SKILL.md` |
| PR review yap | `.claude/skills/review-pr/SKILL.md` |

---

## Xcode Workspace

```bash
open ClaudeBugPoC.xcworkspace
```

> CocoaPods kullanıldığı için **her zaman `.xcworkspace`'i aç**, `.xcodeproj`'i değil.

---

## Pod Yönetimi

```bash
pod install      # Podfile değiştikten sonra
pod update       # Bağımlılıkları güncelle (dikkatli yap)
```

`Pods/` klasörü `.gitignore`'da olmalı; `Podfile.lock` repo'ya commit'lenir.

---

## Konfigürasyon Dosyaları

- `GoogleService-Info.plist` — **gitignored**, sadece local
- `GoogleService-Info.plist.example` — **commit'lenir**, örnek yapı

Yeni cihaza klonlarken:
1. `cp ClaudeBugPoC/GoogleService-Info.plist.example ClaudeBugPoC/GoogleService-Info.plist`
2. Gerçek Firebase config değerlerini doldur.

---

## 💬 Claude'a Nasıl Prompt Yazmalı?

### ✅ Doğru Prompt Örneği

```
Yeni bir MovieDetail ekranı eklemem gerekiyor (push from HomeViewController, movie ID parametresiyle).

NOT: Lütfen önce .claude/skills/ ve .claude/rules/ klasörlerindeki ilgili .md
dosyalarını oku. Özellikle .claude/skills/new-viewcontroller/SKILL.md
dosyasını ve .claude/rules/architecture.md + ui-components.md + viewmodelRule.md
dosyalarını kontrol et.
```

### ✅ Kısa Versiyon

```
MovieDetail ekranı için VC + View + VM scaffold et.
[.claude/skills/new-viewcontroller/SKILL.md kurallarını uygula]
```

### ❌ Yanlış Prompt (KULLANMA)

```
Yeni bir ekran oluştur
```

*(Claude monolitik `ViewController.swift`'i örnek alabilir veya eski generic UIKit pattern'i üretebilir.)*

---

## Mevcut Networking Örneği

`MovieService` mevcut yapıda doğru pattern'i takip ediyor:

- `Networking/Services/MovieService.swift` — enum + `APIService` conformance
- `Networking/Models/Movie.swift` — Decodable model
- `Networking/NetworkManager.swift` — singleton dispatcher

Yeni Service eklerken bu üçlüyü örnek al.

---

## Yapılacaklar (Roadmap Notları)

- [ ] Monolitik `ViewController.swift`'i `Scenes/Chat/` altına parçala
- [ ] AuthService + AuthManager eklenecek (token yönetimi)
- [ ] Refresh token akışı (`NetworkManager` interceptor)
- [ ] Token storage `UserDefaults` → `Keychain` migration
- [ ] Unit test target eklenecek (XCTest)
- [ ] SwiftLint integration

---

**Last Updated:** Mayıs 2026  
**Project:** ClaudeBug iOS PoC
