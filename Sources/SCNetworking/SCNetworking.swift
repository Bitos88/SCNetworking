import Foundation

public extension URLSession {
    func customData(urlReq: URLRequest) async throws(NetworkError) -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await data(for: urlReq)
            guard let respHTTPResp = response as? HTTPURLResponse else {
                throw NetworkError.nonHttp
            }
            return (data, respHTTPResp)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                throw NetworkError.badStatus(-1009, "No internet connection")
            case .timedOut:
                throw NetworkError.badStatus(-1001, "Request timed out")
            default:
                throw NetworkError.general(urlError)
            }
        } catch {
            throw NetworkError.general(error)
        }
    }
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case update = "UPDATE"
    case delete = "DELETE"
}

public extension URLRequest {
    static func APIRequest(url: URL,
                           headers: [String:String]? = nil,
                           httpMethod: HTTPMethod = .get,
                           body: Codable? = nil) throws(NetworkError) -> URLRequest {
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        if let headers {
            headers.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        if let body {
            do {
                let encodedBody = try JSONEncoder().encode(body)
                request.httpBody = encodedBody
            } catch {
                throw .encodingFailed(error)
            }
        }
        return request
    }
}

public enum NetworkError: LocalizedError {
    case nonHttp
    case general(Error)
    case badStatus(Int, String?)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case timeout
    case noInternet

    public var errorDescription: String? {
        switch self {
        case .nonHttp:
            return "The request did not return an HTTP response."
        case .general(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        case .badStatus(let statusCode, let reason):
            return "HTTP Error \(statusCode): \(reason ?? "Unknown error")"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode request body: \(error.localizedDescription)"
        case .unauthorized:
            return "Email o contraseña incorrectos."
        case .forbidden:
            return "No tienes permiso para acceder a este recurso."
        case .notFound:
            return "El recurso solicitado no se encontró."
        case .serverError:
            return "Error interno del servidor. Inténtalo más tarde."
        case .timeout:
            return "La conexión ha tardado demasiado en responder."
        case .noInternet:
            return "No hay conexión a Internet."
        }
    }
}

public protocol NetworkRepositoryProtocol {
    var session: URLSession { get }
}

public extension NetworkRepositoryProtocol {
    func getJSON<MODEL: Codable>(urlReq: URLRequest, model: MODEL.Type, validStatusCodes: Set<Int> = Set(200...299)) async throws(NetworkError) -> MODEL {
            let (data, response) = try await URLSession.shared.customData(urlReq: urlReq)
            
            guard validStatusCodes.contains(response.statusCode) else {
                throw NetworkError.badStatus(response.statusCode, "Unexpected status code")
            }
            
            do {
                return try JSONDecoder().decode(model, from: data)
            } catch let error {
                throw NetworkError.decodingFailed(error)
            }
        }
    
    
    @discardableResult
    func postJSON(urlReq: URLRequest, validStatusCodes: Set<Int> = Set(200...299)) async throws(NetworkError) -> Data? {
        do {
            let (data, response) = try await URLSession.shared.customData(urlReq: urlReq)

            guard !validStatusCodes.contains(response.statusCode) else {
                return data
            }

            let decodedError = try? JSONDecoder().decode(APIResponse.self, from: data)

            throw mapHTTPError(statusCode: response.statusCode, error: decodedError)
            
        } catch let networkError as NetworkError {
            throw networkError
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.general(error)
        }
    }
}

private func mapHTTPError(statusCode: Int, error: APIResponse?) -> NetworkError {
    switch statusCode {
    case 401: return .unauthorized
    case 403: return .forbidden
    case 404: return .notFound
    case 500...599: return .serverError
    default: return .badStatus(statusCode, error?.reason)
    }
}

private func mapURLError(_ urlError: URLError) -> NetworkError {
    switch urlError.code {
    case .notConnectedToInternet: return .noInternet
    case .timedOut: return .timeout
    default: return .general(urlError)
    }
}

struct APIResponse: Codable {
    let reason: String
}
