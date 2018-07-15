import Foundation
import Promises
import SwiftyJSON

extension URLSession {
    func data(url: URL) -> Promise<Data> {
        return Promise<Data> { fulfill, reject in
            let task = self.dataTask(with: url) { data, _, error in
                if let error = error {
                    reject(error)
                } else if let data = data {
                    fulfill(data)
                }
            }
            task.resume()
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

enum HTTPError: Error {
    case noJsonData
    case noData
}
