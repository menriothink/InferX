import Foundation

enum OKRoute {
    case root
    case models([String])
    case modelInfo([String])
    case generate([String])
    case chat([String])
    case copyModel([String])
    case deleteModel([String])
    case pullModel([String])
    case embeddings([String])
    case custom(path: String, method: String)
    
    var path: String {
        let components: [String]
        switch self {
        case .root:
            components = ["/"]
        case .models(let segments),
             .modelInfo(let segments),
             .generate(let segments),
             .chat(let segments),
             .copyModel(let segments),
             .deleteModel(let segments),
             .pullModel(let segments),
             .embeddings(let segments):
            components = segments
        case .custom(let path, _):
            return path
        }

        return components.joined(separator: "/").replacingOccurrences(of: "//", with: "/")
    }
    
    var method: String {
        switch self {
        case .root:
            return "HEAD"
        case .models:
            return "GET"
        case .modelInfo:
            return "POST"
        case .generate:
            return "POST"
        case .chat:
            return "POST"
        case .copyModel:
            return "POST"
        case .deleteModel:
            return "DELETE"
        case .pullModel:
            return "POST"
        case .embeddings:
            return "POST"
        case .custom(_, let method):
            return method
        }
    }
}

struct OKRequest<T: Encodable> {
    let route: OKRoute
    var body: T? = nil
    var headers: [String: String] = [:]
    
    func asURLRequest(baseURL: URL) throws -> URLRequest {
        let url = route.path.isEmpty ? baseURL : baseURL.appendingPathComponent(route.path)
        var request = URLRequest(url: url)
        request.httpMethod = route.method

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.default.encode(body)
        }
        
        return request
    }
}
