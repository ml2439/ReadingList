import Foundation
import Promises
import SwiftyJSON

public extension URLSession {

    /**
     Starts and returns a Data task
    */
    @discardableResult
    func startedDataTask(with url: URL, callback: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let task = dataTask(with: url, completionHandler: callback)
        task.resume()
        return task
    }

    func data(url: URL) -> Promise<Data> {
        return Promise<Data> { fulfill, reject in
            self.startedDataTask(with: url) { data, _, error in
                if let error = error {
                    reject(error)
                } else if let data = data {
                    fulfill(data)
                }
            }
        }
    }

    func json(url: URL) -> Promise<JSON> {
        return self.data(url: url)
            .then { data -> JSON in
                if let jsonData = try? JSON(data: data) {
                    return jsonData
                } else {
                    throw HTTPError.noJsonData
                }
            }
    }
}

public enum HTTPError: Error {
    case noJsonData
}
