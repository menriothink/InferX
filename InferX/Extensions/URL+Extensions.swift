
import Foundation

extension URL {
    func appendingQuery(param: String, value: String?) -> URL? {
        guard var urlComponents = URLComponents(string: self.absoluteString) else { return nil }
        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []
        let queryItem = URLQueryItem(name: param, value: value)
        queryItems.append(queryItem)
        urlComponents.queryItems = queryItems
        return urlComponents.url
    }
}