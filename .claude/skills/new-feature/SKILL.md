---
name: new-feature
description: ClaudeBugPoC iOS uygulaması için tam bir feature modülünü (ViewController + View + ViewModel + Service + Models) tek seferde scaffold eder. Yeni bir bağımsız özellik (örn. Authentication, Profile, Search) eklerken kullan.
---

> ⚠️ Tüm Mandatory rule'lar `.claude/rules/` altındaki dosyalardan gelir. Kod üretmeden önce her zaman:
> - `.claude/rules/architecture.md`
> - `.claude/rules/ui-components.md`
> - `.claude/rules/viewmodelRule.md`
> - `.claude/rules/networking.md`
>
> dosyalarını tara ve uygula.

> ⚠️ **Protocol Stack Rule (Zorunlu):** Her feature'ın View'ları `LayoutableView`, VC'leri `LayoutingViewController`, Cell'leri `LayoutableCollectionViewCell` typealias'larına conform eder. Tek ekran detayları için `.claude/skills/new-viewcontroller/SKILL.md`'ye bak — bu SKILL feature-level orkestrasyona odaklanır.

# New Feature Scaffold (ClaudeBugPoC)

## Ne zaman kullan

- Kullanıcı tamamen yeni, **bağımsız bir feature** istediğinde (`Authentication`, `Profile`, `Search`, `Bookmarks`).
- Feature **kendi API endpoint'leriyle** gelir → `<Feature>Service` + Request/Response model'leri de gerekir.
- Tek bir ekran yerine **birden fazla ekran** içerebilir.

## `new-viewcontroller`'dan farkı

| Skill | Kapsam |
|-------|--------|
| `new-viewcontroller` | Tek bir ekran (1 VC + 1 View + 1 VM) |
| `new-feature` | Bağımsız bir feature: 1+ ekran + Service + Models + (varsa) Manager |

## Akış

1. Feature'ı netleştir (ad, ana ekranlar, API ihtiyaçları).
2. Klasör ağacını çiz.
3. **Service** dosyasını üret.
4. **Request/Response Model'leri** üret.
5. (Gerekirse) **Manager** singleton üret (auth, session, vb.).
6. Her bir ekran için VC + View + VM üret.
7. Navigation graph'ı VC seviyesinde delegate üzerinden bağla.

## Proje Konvansiyonu

```
ClaudeBugPoC/
├── Scenes/<FeatureName>/
│   ├── <ScreenA>/
│   │   ├── <ScreenA>ViewController.swift
│   │   ├── <ScreenA>View.swift
│   │   └── <ScreenA>ViewModel.swift
│   └── <ScreenB>/
│       └── ...
├── Networking/
│   ├── Services/
│   │   └── <FeatureName>Service.swift
│   └── Models/
│       ├── <FeatureName>Request.swift
│       └── <FeatureName>Response.swift
└── Managers/                      # gerekirse (Auth, Session)
    └── <FeatureName>Manager.swift
```

## Detaylı Adımlar

### 1. Gereksinim toplama

Sor:

- **Feature adı** (örn. `Authentication`)
- **Ekranlar** (örn. `Login`, `Register`, `ForgotPassword`)
- **API endpoints** (örn. `POST /auth/login`, `POST /auth/register`)
- **Persistence ihtiyacı** (token kaydı, session)
- **Manager gerekiyor mu?** (singleton lazımsa)

Şablon:

```
Feature: Authentication
Screens:
  - Login (entry point)
  - Register (push from Login)
  - ForgotPassword (push from Login)
Endpoints:
  - POST /auth/login → returns AccessToken
  - POST /auth/register → returns AccessToken
  - POST /auth/forgot-password → returns void
Persistence: AccessToken UserDefaults'a kaydedilir
Manager: AuthManager (token tutar, logout yapar)
```

### 2. Service Dosyası

```swift
//
//  AuthService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum AuthService: APIService {
    case login(email: String, password: String)
    case register(email: String, password: String, name: String)
    case forgotPassword(email: String)
}

extension AuthService {
    var baseURL: URL { ApiConstant.baseURL }

    var path: String {
        switch self {
        case .login: return "auth/login"
        case .register: return "auth/register"
        case .forgotPassword: return "auth/forgot-password"
        }
    }

    var method: HTTPMethod { .post }

    var headers: HTTPHeaders? { ApiConstant.getHeaders() }

    var parameters: Parameters? {
        switch self {
        case .login(let email, let password):
            return ["email": email, "password": password]
        case .register(let email, let password, let name):
            return ["email": email, "password": password, "name": name]
        case .forgotPassword(let email):
            return ["email": email]
        }
    }

    var encoding: ParameterEncoding { JSONEncoding.default }
}
```

> Detay: `.claude/rules/networking.md` + `.claude/skills/networking-service/SKILL.md`

### 3. Response Modelleri

```swift
//
//  AuthResponse.swift
//  ClaudeBugPoC
//

import Foundation

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct User: Decodable {
    let id: Int
    let email: String
    let name: String
}
```

### 4. Manager (Opsiyonel)

```swift
//
//  AuthManager.swift
//  ClaudeBugPoC
//

import Foundation

final class AuthManager {

    // MARK: - Singleton
    static let shared = AuthManager()
    private init() {}

    // MARK: - Storage Keys
    private enum Keys {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
    }

    // MARK: - Public
    var isLoggedIn: Bool {
        return accessToken != nil
    }

    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: Keys.accessToken) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.accessToken) }
    }

    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: Keys.refreshToken) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.refreshToken) }
    }

    func save(_ response: AuthResponse) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
    }
}
```

> **Not:** Token'lar UserDefaults yerine `Keychain`'e kaydedilmeli — şimdilik PoC için UserDefaults kabul, **production öncesi mutlaka değiştir**.

### 5. Ekranlar

Her ekran için `new-viewcontroller` skill'inin tam akışını uygula:

- `LoginViewController` (`LayoutingViewController`) + `LoginView` (`LayoutableView`) + `LoginViewModel`
- `RegisterViewController` + `RegisterView` + `RegisterViewModel`
- `ForgotPasswordViewController` + `ForgotPasswordView` + `ForgotPasswordViewModel`

Her VC'nin iskeleti:

```swift
final class LoginViewController: LayoutingViewController {
    typealias ViewType = LoginView
    private let viewModel: LoginViewModel
    // init, loadView (view = ViewType.create()), viewDidLoad...
}
```

Her View'in iskeleti:

```swift
final class LoginView: LayoutableView {
    // lazy var subview'lar

    func setupViews() {
        backgroundColor = .systemBackground
        // addSubview'lar
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        // SnapKit constraint'leri
    }
}
```

Her VM'in delegate'i kendi feature suffix'ini taşır:

```swift
protocol LoginViewModelDelegate: AnyObject {
    func loginViewModelDidStartLoading()
    func loginViewModelDidFinishLoading()
    func loginViewModelDidLoginSuccessfully()
    func loginViewModelDidFailWith(error: Error)
}
```

### 6. Network → Manager → Navigation akışı

```swift
// LoginViewModel
private func performLogin(email: String, password: String) {
    delegate?.loginViewModelDidStartLoading()

    NetworkManager.shared.request(service: AuthService.login(email: email, password: password)) { [weak self] (result: Result<AuthResponse, AFError>) in
        guard let self else { return }
        self.delegate?.loginViewModelDidFinishLoading()

        switch result {
        case .success(let response):
            AuthManager.shared.save(response)
            self.delegate?.loginViewModelDidLoginSuccessfully()
        case .failure(let error):
            self.delegate?.loginViewModelDidFailWith(error: error)
        }
    }
}

// LoginViewController
func loginViewModelDidLoginSuccessfully() {
    // root'u değiştir veya home'a navigate et
    let homeVM = HomeViewModel()
    let homeVC = HomeViewController(viewModel: homeVM)
    let nav = UINavigationController(rootViewController: homeVC)
    view.window?.rootViewController = nav
}
```

## Sık Yapılan Hatalar

| Hata | Doğrusu |
|------|--------|
| Tüm feature'ı tek dosyada üretmek | Her ekran kendi klasörü + 3 dosyası |
| Çıplak `UIView` / `UIViewController` subclass'ı | `LayoutableView` / `LayoutingViewController` typealias'ı |
| Service'i ekran VC'sinin içinde tanımlamak | `Networking/Services/` altında **enum** |
| Manager'ı her feature için eklemek | Manager **gerçekten** singleton state gerekiyorsa ekle, değilse atla |
| Token'ı UserDefaults'a düz yazmak ve unutmak | TODO comment ekle: "Production öncesi Keychain'e taşı" |
| Navigation'ı ViewModel'den tetiklemek | Delegate ile VC'ye ilet, VC navigation yapar |
| View'da `override init(frame:)` | YAZMA — `.create()` factory halleder |

## Çıktı Checklist

- [ ] `Scenes/<Feature>/<Screen>/` klasörleri açıldı
- [ ] Her ekran için VC + View + VM üretildi
- [ ] Her View `LayoutableView` typealias'ına conform
- [ ] Her VC `LayoutingViewController` typealias'ına conform + `typealias ViewType = <Name>View`
- [ ] (Varsa) Cell'ler `LayoutableCollectionViewCell` conform
- [ ] `Networking/Services/<Feature>Service.swift` enum oluşturuldu
- [ ] `Networking/Models/<Feature>Response.swift` (ve gerekirse Request) modelleri var
- [ ] (Gerekiyorsa) `Managers/<Feature>Manager.swift` oluşturuldu
- [ ] Navigation flow her VC'nin delegate handler'larında bağlandı
- [ ] Her dosyada MARK / backgroundColor / weak delegate / `generateAccessibilityIdentifiers` kuralları uygulandı
- [ ] TODO'lar yazıldı (Keychain migration, refresh token, vb.)

## İlgili Skill'ler & Kurallar

- `.claude/skills/new-viewcontroller/SKILL.md` (her ekran için)
- `.claude/skills/networking-service/SKILL.md` (Service için)
- `.claude/rules/architecture.md`
- `.claude/rules/networking.md`
- `.claude/rules/ui-components.md`
- `.claude/rules/viewmodelRule.md`
