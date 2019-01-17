import Foundation
import Swifter

class MockServer {
    let server = HttpServer()
    private let searchedIsbns = ["9781111111111", "9780547345666", "9781781100264"]
    private let fetchedGoogleBookIds = ["gCtazG4ZXlQC"]

    init() {
        for isbn in searchedIsbns {
            server.get[GoogleBooksRequest.searchIsbn(isbn).relativePath] = { _ in
                HttpResponse.ok(.json(self.jsonFromFile(withName: "Search_\(isbn)", ofType: "json") as AnyObject))
            }
        }
        for googleBookId in fetchedGoogleBookIds {
            server.get[GoogleBooksRequest.fetch(googleBookId).relativePath] = { _ in
                HttpResponse.ok(.json(self.jsonFromFile(withName: "Fetch_\(googleBookId)", ofType: "json") as AnyObject))
            }
        }
    }
    
    private func jsonFromFile(withName name: String, ofType fileType: String) -> Any {
        let path = Bundle(for: type(of: self)).path(forResource: name, ofType: fileType)!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))
        return try! JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}
