//
//  NetworkManager.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

final class NetworkManager {
    static let shared = NetworkManager()

    private let shortTimeoutSession: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        return Session(configuration: configuration)
    }()

    private let longTimeoutSession: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 40
        return Session(configuration: configuration)
    }()

    private init() {}

    // MARK: - Generic Decodable Request
    func request<T: Decodable>(
        service: APIService,
        completion: @escaping (Result<T, AFError>) -> Void
    ) {
        if let error = checkNetworkReachability() {
            completion(.failure(error))
            return
        }

        let helper = ApiRequestHelper(service)
        let url = helper.fullURL
        let session = selectedSession(for: service)
        let startTime = Date()

        session.request(
            url,
            method: service.method,
            parameters: service.parameters,
            encoding: service.encoding,
            headers: helper.requestHeaders
        )
        .validate()
        .responseDecodable(of: T.self) { response in
            let statusCode = response.response?.statusCode
            let duration = Date().timeIntervalSince(startTime)

            self.log(
                path: service.path,
                statusCode: statusCode,
                duration: duration,
                data: response.data,
                error: response.error
            )

            if statusCode == 401 {
                completion(.failure(.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))))
                return
            }

            switch response.result {
            case .success(let decoded):
                completion(.success(decoded))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Reachability
    func isNetworkReachable() -> Bool {
        let state = NetworkReachabilityManager()?.status
        return state != .unknown && state != .notReachable
    }
}

// MARK: - Private Helpers
private extension NetworkManager {
    func selectedSession(for service: APIService) -> Session {
        return service.path.hasPrefix("movie/popular") ? shortTimeoutSession : longTimeoutSession
    }

    func checkNetworkReachability() -> AFError? {
        guard isNetworkReachable() else {
            let error = AFError.sessionTaskFailed(
                error: NSError(
                    domain: "NetworkManager",
                    code: -1009,
                    userInfo: [NSLocalizedDescriptionKey: "Please check your network."]
                )
            )
            return error
        }
        return nil
    }

    func log(path: String, statusCode: Int?, duration: TimeInterval, data: Data?, error: AFError?) {
        #if DEBUG
        print("──────── 🌐 NetworkManager ────────")
        print("📍 path: \(path)")
        print("📦 status: \(statusCode.map(String.init) ?? "-")")
        print("⏱ duration: \(String(format: "%.2fs", duration))")
        if let error {
            print("❌ error: \(error.localizedDescription)")
        }
        if let data {
            let body = String(data: data, encoding: .utf8) ?? "-"
            let truncated = body.count > 500 ? String(body.prefix(500)) + "…" : body
            print("📨 body: \(truncated)")
        }
        print("───────────────────────────────────")
        #endif
    }
}
