# ClaudeBugPoC iOS — Networking Rules

> **Applies to:** `ClaudeBugPoC/Networking/` altındaki tüm Swift dosyaları + her tür HTTP/Firebase çağrısı.

---

## 1. Temel Kurallar

> **ZORUNLU:** Tüm HTTP istekleri `NetworkManager.shared.request(service:)` üzerinden gider. `URLSession`, `URLRequest`, custom `Alamofire.Session` doğrudan kullanılamaz.

> **ZORUNLU:** Her endpoint **bir `APIService` enum case'i** olarak modellenir. Magic string URL kabul edilmez.

> **ZORUNLU:** Tüm response'lar `Decodable` model'e parse edilir — `[String: Any]` JSONSerialization yasak.

> **ZORUNLU:** Tüm request/response model'leri `Networking/Models/` altında, **feature klasörüne ayrılmış** halde durur.

---

## 2. Mevcut Networking Yapısı

```
ClaudeBugPoC/Networking/
├── APIService.swift              # Protocol (her endpoint conform eder)
├── NetworkManager.swift          # Singleton dispatch + reachability + log
├── Constants/
│   ├── ApiConstant.swift         # baseURL, headers, path enum
│   └── ApiError.swift            # Custom error tipleri
├── Helpers/
│   ├── ApiRequestHelper.swift    # Header / fullURL inşası
│   └── ApiResponseHelper.swift   # Response parsing helpers
├── Models/                       # Decodable model'ler (feature'a göre grupla)
│   ├── Movie.swift
│   └── MovieDetail.swift
└── Services/                     # Her feature için bir APIService enum
    └── MovieService.swift
```

---

## 3. APIService Protocol

```swift
protocol APIService {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: HTTPHeaders? { get }
    var parameters: Parameters? { get }
    var encoding: ParameterEncoding { get }
}
```

Yeni endpoint eklerken bu protokole conform eden bir **enum** oluştur. Endpoint başına bir **case**, parametreler associated value.

---

## 4. Yeni Service Şablonu

```swift
//
//  AuthService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum AuthService: APIService {
    case login(email: String, password: String)
    case refreshToken(refresh: String)
    case logout
}

extension AuthService {
    var baseURL: URL {
        return ApiConstant.baseURL
    }

    var path: String {
        switch self {
        case .login: return "auth/login"
        case .refreshToken: return "auth/refresh"
        case .logout: return "auth/logout"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .refreshToken: return .post
        case .logout: return .delete
        }
    }

    var headers: HTTPHeaders? {
        return ApiConstant.getHeaders()
    }

    var parameters: Parameters? {
        switch self {
        case .login(let email, let password):
            return ["email": email, "password": password]
        case .refreshToken(let refresh):
            return ["refresh_token": refresh]
        case .logout:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .login, .refreshToken: return JSONEncoding.default
        case .logout: return URLEncoding.default
        }
    }
}
```

**Önemli kurallar:**
- Tek bir `extension` block içinde tüm protocol property'lerini topla (ayrı extension'lara dağıtma).
- `switch self` ile case'lere göre değer üret — default case kullanma (compiler exhaustiveness check'ini koru).
- `headers` global header'ları `ApiConstant.getHeaders()` ile çek; endpoint-spesifik header'ları gerekirse merge et.

---

## 5. Request Çağrısı

ViewModel içinde:

```swift
NetworkManager.shared.request(service: MovieService.popular(page: 1)) { [weak self] (result: Result<MovieListResponse, AFError>) in
    guard let self else { return }
    switch result {
    case .success(let response):
        self.items = response.results
        self.delegate?.viewModelDidUpdateItems()
    case .failure(let error):
        self.delegate?.viewModelDidFailWith(error: error)
    }
}
```

**Kurallar:**
- `[weak self]` zorunlu (long-running call).
- Generic `<T: Decodable>` tipini explicit yaz (`Result<MovieListResponse, AFError>`).
- Hata `delegate` üzerinden VC'ye iletilir, doğrudan `presentAlert` ViewModel'de yapılmaz.

---

## 6. Response Modeli

```swift
struct MovieListResponse: Decodable {
    let page: Int
    let results: [Movie]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}
```

**Kurallar:**
- `snake_case` field'lar için `CodingKeys` ile mapping yap. Global decoder strategy ile `convertFromSnakeCase` **şu an kullanılmıyor** — açıkça yaz.
- Optional field'lar: backend gerçekten nullable döndürüyorsa `Optional`, garanti varsa non-optional.
- Date alanları: `String` olarak oku, display sırasında parse et (ileride DateFormatter kuralı eklenecek).

---

## 7. Hata Yönetimi

### Network seviyesi
- `AFError.sessionTaskFailed` → no internet / timeout
- `AFError.responseValidationFailed(reason: .unacceptableStatusCode(401))` → auth gerekiyor

### Uygulama seviyesi
- 401 → refresh token akışı (henüz implement edilmedi, TODO)
- 4xx → kullanıcı dostu hata mesajı
- 5xx → "Sunucu hatası, tekrar deneyin"

**ViewModel'de tek noktada handle et, VC'ye `Error` yerine domain error ilet** (PoC ölçeğinde şimdilik raw `AFError` geçmek kabul):

```swift
enum HomeError: Error {
    case noNetwork
    case unauthorized
    case server(String)
    case unknown
}
```

---

## 8. Reachability

`NetworkManager.shared.isNetworkReachable()` ile kontrol et. Manuel `Reachability` kütüphanesi ekleme — Alamofire'ınkini kullan.

```swift
guard NetworkManager.shared.isNetworkReachable() else {
    delegate?.viewModelDidFailWith(error: HomeError.noNetwork)
    return
}
```

---

## 9. Firebase Functions Çağrıları

`FirebaseFunctions` kullanan call'lar **`NetworkManager` üzerinden geçmez** — direkt SDK'den çağır, ama wrapper'ı `Managers/` altına yerleştir:

```swift
final class CloudFunctionsManager {
    static let shared = CloudFunctionsManager()
    private lazy var functions = Functions.functions()

    private init() {}

    func callProposeChange(payload: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        functions.httpsCallable("proposeChange").call(payload) { result, error in
            // ...
        }
    }
}
```

**Yasak:** Firebase SDK'sını ViewController içinden doğrudan çağırma — Manager wrapper kullan.

---

## 10. AppCheck

`FirebaseAppCheck` zorunlu — `AppDelegate.application(_:didFinishLaunchingWithOptions:)` içinde provider'ı set et:

```swift
let providerFactory = AppCheckDebugProviderFactory()  // sadece DEBUG
AppCheck.setAppCheckProviderFactory(providerFactory)
FirebaseApp.configure()
```

Release build'lerde `DeviceCheck` veya `AppAttest` provider'ı kullan.

---

## 11. Logging & Privacy

- `NetworkManager.log(...)` `#if DEBUG` arkasında — release build'de **kapalı**.
- Header'larda `Authorization: Bearer <token>` log'a yazılmaz (ApiRequestHelper'da redact et).
- PII (e-mail, telefon, kart no) hiçbir log'a yazılmaz.

---

## 12. Test Edilebilirlik

- ViewModel test'lerinde `NetworkManager.shared` yerine bir **`NetworkService` protokolü** mock'lanabilir hale getirilecek (TODO — şimdilik integration test).
- Service'ler enum olduğu için kolayca test edilir: `XCTAssertEqual(MovieService.popular(page: 1).path, "movie/popular")`.

---

## 13. Yeni Endpoint Eklerken Checklist

- [ ] `Networking/Services/<Feature>Service.swift` enum oluştur (yoksa)
- [ ] Yeni `case` ekle, associated value'ları parametrelerle eşle
- [ ] `path`, `method`, `parameters`, `encoding` switch'lerine case'i ekle
- [ ] `Networking/Models/<Feature>Response.swift` Decodable model yaz
- [ ] (Varsa) `Networking/Models/<Feature>Request.swift` Encodable model yaz
- [ ] ViewModel'de `NetworkManager.shared.request(service:)` çağrısını yaz
- [ ] Hata akışını delegate'e ilet
- [ ] (Opsiyonel) Unit test: enum property'leri için doğru değer döndürdüğünü doğrula

> **İlgili skill:** `.claude/skills/networking-service/SKILL.md`
