import Foundation

public extension URLSession {
    func customData(urlReq: URLRequest) async throws(NetworkError) -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await data(for: urlReq)
            guard let respHTTPResp = response as? HTTPURLResponse else {
                throw NetworkError.nonHttp
            }
            return (data, respHTTPResp)
        } catch let error {
            throw NetworkError.general(error)
        }
    }
}

public enum NetworkError: LocalizedError {
    case nonHttp
    case general(Error)
    case badStatusCode(Int)
    case errorDecode(Error)
    case errorEncode(Error)
    
    public var errorDescription: String {
        switch self {
        case .nonHttp:
            "Non HTTp request"
        case .general(let myError):
            "General Error \(myError)"
        case .badStatusCode (let statusCode):
            "Wrong Status code\(statusCode)"
        case .errorDecode (let decodeError):
            "error Decode\(decodeError)"
        case .errorEncode(let encodedError):
            "error Encode\(encodedError)"
        }
    }
}

public enum HTTTMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case update = "UPDATE"
    case delete = "DETELE"
}

public extension URLRequest {
    static func APIRequest(url: URL,
                           headers: [String:String]? = nil,
                           httpMethod: HTTTMethod = .get,
                           body: Codable? = nil) throws(NetworkError) -> URLRequest {
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
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
                throw .errorEncode(error)
            }
        }
        
        return request
    }
}

public protocol NetworkRepositoryProtocol {
    var session: URLSession { get }
}

public extension NetworkRepositoryProtocol {
    func getJSON<MODEL>(urlReq: URLRequest, model: MODEL.Type) async throws(NetworkError) -> MODEL where MODEL:Codable  {
        let (data, response) = try await URLSession.shared.customData(urlReq: urlReq)
        if response.statusCode == 200 {
            do {
                return try JSONDecoder().decode(model, from: data)
            } catch let error {
                throw NetworkError.errorDecode(error)
            }
        } else {
            throw NetworkError.badStatusCode(response.statusCode)
        }
    }
}

