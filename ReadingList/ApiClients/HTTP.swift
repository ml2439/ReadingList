import Foundation
import SwiftyJSON

class HTTP {

    enum HTTPError: Error {
        case noJsonData
        case noData
    }
    
    class Request {
        private let request: URLRequest
        private var task: URLSessionDataTask?
        
        private init(_ request: URLRequest) {
            self.request = request
        }
        
        static func get(url: URL) -> Request {
            return Request(URLRequest(url: url))
        }
        
        @discardableResult func json(callback: @escaping (Result<JSON>) -> Void) -> Request {
            task = URLSession.shared.dataTask(with: request) { (data, _, error) in
                DispatchQueue.main.async {
                    guard error == nil else { callback(Result.failure(error!)); return }
                    guard let json = JSON(optionalData: data) else { callback(Result.failure(HTTPError.noJsonData)); return }
                    callback(Result<JSON>.success(json))
                }
            }
            task!.resume()
            return self
        }
        
        @discardableResult func data(callback: @escaping (Result<Data>) -> Void) -> Request {
            task = URLSession.shared.dataTask(with: request) { (data, _, error) in
                DispatchQueue.main.async {
                    guard error == nil else { callback(Result.failure(error!)); return }
                    guard let data = data else { callback(Result.failure(HTTPError.noData)); return }
                    callback(Result<Data>.success(data))
                }
            }
            task!.resume()
            return self
        }
        
        func cancel() {
            task?.cancel()
        }
    }
}
