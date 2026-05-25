---
name: networking-service
description: ClaudeBugPoC iOS uygulamasında yeni bir APIService enum'u + Request/Response model'lerini scaffold eder. Yeni bir backend endpoint'i eklendiğinde veya mevcut bir Service'e yeni case eklerken kullan.
---

> ⚠️ Tüm HTTP istekleri **`NetworkManager.shared.request(service:)`** üzerinden gider. `URLSession` doğrudan, magic string URL, `[String: Any]` JSONSerialization yasak. Canonical: `.claude/rules/networking.md`.

# New APIService (Networking) Scaffold

## Ne zaman kullan

- Yeni bir backend endpoint'i tüketmek gerektiğinde.
- Henüz hiç Service'i olmayan bir feature için ilk endpoint'i eklerken (`<Feature>Service` enum'unu sıfırdan).
- Mevcut bir Service'e yeni `case` eklerken.

## Akış

1. Endpoint özelliklerini netleştir (method, path, parametre, response model).
2. Service enum dosyasını oluştur (yoksa) veya mevcut olana case ekle.
3. Response model'i Decodable struct olarak yaz.
4. (Gerekirse) Request model'i Encodable struct olarak yaz.
5. Call'u ViewModel içinde örnekle.

## Detaylı Adımlar

### 1. Endpoint Spec Topla

Sor / netleştir:

| Alan | Örnek |
|------|-------|
| Method | `GET` / `POST` / `PUT` / `DELETE` |
| Path | `auth/login`, `movie/123/credits` |
| Query/body params | `email`, `password` |
| Response shape | JSON şeması veya backend doküman |
| Auth gerektirir mi? | Yes/No (Authorization header) |
| Endpoint'in hangi Service enum'una eklenmesi gerekiyor? | `MovieService`, `AuthService`, yeni `XService` |

### 2. Service Enum

#### Yeni Service oluştur

```swift
//
//  SearchService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum SearchService: APIService {
    case movies(query: String, page: Int)
    case people(query: String)
}

extension SearchService {
    var baseURL: URL { ApiConstant.baseURL }

    var path: String {
        switch self {
        case .movies: return "search/movie"
        case .people: return "search/person"
        }
    }

    var method: HTTPMethod { .get }

    var headers: HTTPHeaders? { ApiConstant.getHeaders() }

    var parameters: Parameters? {
        switch self {
        case .movies(let query, let page):
            return ["query": query, "page": page, "language": "en-US"]
        case .people(let query):
            return ["query": query, "language": "en-US"]
        }
    }

    var encoding: ParameterEncoding { URLEncoding.default }
}
```

#### Mevcut Service'e case ekle

`MovieService.swift`'i aç ve:

```swift
enum MovieService: APIService {
    case popular(page: Int)
    case detail(id: Int)
    case nowPlaying(page: Int)     // ← yeni
}

// path
case .nowPlaying: return "movie/now_playing"

// method (zaten .get default)

// parameters
case .nowPlaying(let page):
    return ["page": page, "language": "en-US"]
```

**Önemli:**
- Her case'i **tüm switch block'larına** ekle (path, method, parameters, headers gerekiyorsa, encoding gerekiyorsa).
- Default case kullanma — compiler exhaustiveness check'i sayesinde unutmazsın.

### 3. Response Model

Backend'in döndürdüğü JSON şu ise:

```json
{
  "page": 1,
  "results": [
    { "id": 123, "title": "Foo", "vote_average": 7.5 }
  ],
  "total_pages": 100,
  "total_results": 2000
}
```

Karşılığı:

```swift
//
//  MovieListResponse.swift
//  ClaudeBugPoC
//

import Foundation

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

struct Movie: Decodable {
    let id: Int
    let title: String
    let voteAverage: Double

    enum CodingKeys: String, CodingKey {
        case id, title
        case voteAverage = "vote_average"
    }
}
```

**Kurallar:**
- `snake_case` JSON → `camelCase` Swift mapping `CodingKeys` ile.
- Optional/non-optional kararı backend kontratına göre — backend `null` döndürebiliyorsa `Optional`.
- Tarih alanları `String` olarak tut (display'de parse et).

### 4. Request Body Model (POST/PUT için)

`Parameters?` ile `[String: Any]` döndürmek yerine **Encodable struct** kullanmak daha güvenli:

```swift
//
//  LoginRequest.swift
//  ClaudeBugPoC
//

import Foundation

struct LoginRequest: Encodable {
    let email: String
    let password: String
}
```

Servis tarafında parametre olarak struct'ı dictionary'ye dönüştür (alternatif: `URLRequest` body'sini doğrudan encode etmek için NetworkManager'a `Encodable` overload eklemek — şimdilik dictionary yeterli).

```swift
case .login(let request):
    return [
        "email": request.email,
        "password": request.password
    ]
```

### 5. ViewModel'den Call

```swift
import Foundation
import Alamofire

private func search(query: String) {
    NetworkManager.shared.request(service: SearchService.movies(query: query, page: 1)) { [weak self] (result: Result<MovieListResponse, AFError>) in
        guard let self else { return }
        switch result {
        case .success(let response):
            self.results = response.results
            self.delegate?.searchViewModelDidUpdateResults()
        case .failure(let error):
            self.delegate?.searchViewModelDidFailWith(error: error)
        }
    }
}
```

## Sık Yapılan Hatalar

| Hata | Doğrusu |
|------|--------|
| `let url = URL(string: "https://api...")!` | Service enum'a case ekle |
| `URLSession.shared.dataTask(...)` | `NetworkManager.shared.request(service:)` |
| `JSONSerialization.jsonObject(with: data)` | `Decodable` struct |
| Default case ile fallthrough | Exhaustive switch — her case'i açıkça yaz |
| Service property'lerini ayrı extension'larda | Tek `extension <Name>Service { ... }` block'u |
| `[String: Any]` parametre + magic string key | Encodable struct + Service'te dictionary'ye çevir (geçici) |
| `convertFromSnakeCase` global decoder strategy beklemek | Local `CodingKeys` ile mapping |
| Auth header'ı her case'de manuel set etmek | `ApiConstant.getHeaders()` ile merkezi |

## Çıktı Checklist

- [ ] Service enum yeni dosyada veya mevcut dosyaya case eklendi
- [ ] `path`, `method`, `parameters`, `encoding` switch'lerine yeni case eklendi
- [ ] Response model `Networking/Models/` altında Decodable struct
- [ ] (Varsa) Request model Encodable struct
- [ ] `CodingKeys` snake_case → camelCase mapping yapıldı
- [ ] ViewModel call'u `[weak self]` + explicit generic tip ile yazıldı
- [ ] Hata akışı delegate üzerinden VC'ye iletildi

## İlgili Kurallar

- `.claude/rules/networking.md` (kapsamlı kurallar)
- `.claude/rules/architecture.md` (modül yapısı)
- `.claude/rules/viewmodelRule.md` (ViewModel'den call pattern)
