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
                    guard let data = data else { callback(Result.failure(HTTPError.noJsonData)); return }
                    callback(Result<JSON>.success(JSON(data: data)))
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


enum Result<Value> {
    case success(Value)
    case failure(Error)
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var value: Value? {
        switch self {
        case let .success(value):
            return value
        case .failure:
            return nil
        }
    }
    
    var error: Error? {
        switch self {
        case let .failure(error):
            return error
        case .success:
            return nil
        }
    }
    
    func toOptional() -> Result<Value?> {
        switch self {
        case let .success(value):
            return Result<Value?>.success(value)
        case let .failure(error):
            return Result<Value?>.failure(error)
        }
    }
}

