import Foundation
import SwiftyJSON

class GoogleBooks {

    /**
     Searches on Google Books for the given search string, and calls the callback when a result is received
    */
    @discardableResult
    static func search(_ text: String, callback: @escaping (SearchResultsPage) -> Void) -> HTTP.Request {
        return HTTP.Request.get(url: Request.searchText(text).url).json { result in

            // Check for HTTP error
            guard result.isSuccess else { callback(SearchResultsPage.error(result.error!, fromSearchText: text)); return }

            // Check for errors reported by Google
            let googleError = Parser.parseError(json: result.value!)
            guard googleError == nil else { callback(SearchResultsPage.error(googleError!, fromSearchText: text)); return }

            let results = Parser.parseSearchResults(result.value!)
            callback(SearchResultsPage(results, fromSearchText: text))
        }
    }

    /**
     Searches on Google Books for the given search string, and calls the callback when a result is received.
     */
    static func fetch(isbn: String, callback: @escaping (FetchResultPage) -> Void) {
        let googleRequest = Request.searchIsbn(isbn)
        HTTP.Request.get(url: googleRequest.url).json { result in

            // Check for HTTP errors
            guard result.isSuccess else { callback(FetchResultPage.error(result.error!, fromRequest: googleRequest)); return }

            // Check for errors reported by Google
            let googleError = Parser.parseError(json: result.value!)
            guard googleError == nil else { callback(FetchResultPage.error(googleError!, fromRequest: googleRequest)); return }

            let results = Parser.parseSearchResults(result.value!)
            guard let id = results.first?.id else { callback(FetchResultPage.empty(fromRequest: googleRequest)); return }
            GoogleBooks.fetch(googleBooksId: id, callback: callback)
        }
    }

    /**
     Fetches the specified book from Google Books.
     */
    static func fetch(googleBooksId: String, callback: @escaping (FetchResultPage) -> Void) {
        let request = Request.fetch(googleBooksId)
        HTTP.Request.get(url: request.url).json { result in
            // Check for HTTP errors
            guard result.isSuccess else { callback(FetchResultPage.error(result.error!, fromRequest: request)); return }

            // Check for errors reported by Google
            let googleError = Parser.parseError(json: result.value!)
            guard googleError == nil else { callback(FetchResultPage.error(googleError!, fromRequest: request)); return }

            guard let result = Parser.parseFetchResults(result.value!) else { callback(FetchResultPage.empty(fromRequest: request)); return }

            getCover(googleBooksId: result.id) { coverResult in
                if coverResult.isSuccess {
                    result.coverImage = coverResult.value!
                }
                callback(FetchResultPage(result, fromRequest: request))
            }
        }
    }

    /**
     Gets the cover image data for the book corresponding to the Google Books ID (if exists).
    */
    static func getCover(googleBooksId: String, callback: @escaping (Result<Data>) -> Void) {
        // Just use the thumbnail cover images for now
        let coverRequest = Request.coverImage(googleBooksId, .thumbnail)
        HTTP.Request.get(url: coverRequest.url).data(callback: callback)
    }

    static func getCover(isbn: String, callback: @escaping (Result<Data>) -> Void) {
        // If we are going by the ISBN, fetch the result first
        // This could become redundant if we supplement ISBN -> GBID first.
        GoogleBooks.fetch(isbn: isbn) { fetchResult in
            guard fetchResult.result.isSuccess else { callback(Result.failure(fetchResult.result.error!)); return }

            getCover(googleBooksId: fetchResult.result.value!.id) { coverResult in
                callback(coverResult)
            }
        }
    }

    enum Request {

        case searchText(String)
        case searchIsbn(String)
        case fetch(String)
        case coverImage(String, CoverType)
        case webpage(String)

        enum CoverType: Int {
            case thumbnail = 1
            case small = 2
        }

        // The base URL for GoogleBooks API v1 requests
        private static let apiBaseUrl = URL(string: "https://www.googleapis.com/")!
        private static let googleBooksBaseUrl = URL(string: "https://books.google.com/")!

        private static let searchResultFields = "items(id,volumeInfo(title,authors,industryIdentifiers,categories,imageLinks/thumbnail))"

        var url: URL {
            switch self {
            case let .searchText(searchString):
                let encodedQuery = searchString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                let relativeUrl = "books/v1/volumes?q=\(encodedQuery)&maxResults=40&fields=\(Request.searchResultFields)"
                return URL(string: relativeUrl, relativeTo: Request.apiBaseUrl)!

            case let .searchIsbn(isbn):
                let relativeUrl = "books/v1/volumes?q=isbn:\(isbn)&maxResults=40&fields=\(Request.searchResultFields)"
                return URL(string: relativeUrl, relativeTo: Request.apiBaseUrl)!

            case let .fetch(id):
                return URL(string: "books/v1/volumes/\(id)", relativeTo: Request.apiBaseUrl)!

            case let .coverImage(googleBooksId, coverType):
                return URL(string: "books/content?id=\(googleBooksId)&printsec=frontcover&img=1&zoom=\(coverType.rawValue)", relativeTo: Request.googleBooksBaseUrl)!

            case let .webpage(googleBooksId):
                return URL(string: "books?id=\(googleBooksId)", relativeTo: Request.googleBooksBaseUrl)!
            }
        }
    }

    class Parser {

        static func parseError(json: JSON) -> GoogleError? {
            if let code = json["error", "code"].int, let message = json["error", "message"].string {
                return GoogleError(code: code, message: message)
            }
            return nil
        }

        static func parseSearchResults(_ searchResults: JSON) -> [SearchResult] {
            return searchResults["items"].compactMap { itemJson in
                return Parser.parseItem(itemJson.1)
            }
        }

        static func parseItem(_ item: JSON) -> SearchResult? {
            guard let id = item["id"].string,
                let title = item["volumeInfo", "title"].string,
                let authors = item["volumeInfo", "authors"].array else { return nil }

            let result = SearchResult(id: id, title: title, authors: authors.map {$0.rawString()!})

            // Convert the thumbnail URL to HTTPS
            if let thumbnailUrlString = item["volumeInfo", "imageLinks", "thumbnail"].string,
                let thumbnailUrl = URL(string: thumbnailUrlString) {
                var urlComponents = URLComponents(url: thumbnailUrl, resolvingAgainstBaseURL: false)!
                urlComponents.scheme = "https"
                result.thumbnailCoverUrl = urlComponents.url
            }
            result.isbn13 = item["volumeInfo", "industryIdentifiers"].array?.first(where: { json in
                return json["type"].stringValue == "ISBN_13"
            })?["identifier"].stringValue

            return result
        }

        static func parseFetchResults(_ fetchResult: JSON) -> FetchResult? {

            // Defer to the common search parsing initially
            guard let searchResult = Parser.parseItem(fetchResult) else { return nil }

            let result = FetchResult(fromSearchResult: searchResult)
            result.pageCount = fetchResult["volumeInfo", "pageCount"].int
            // "Published Date" refers to *this* edition; there doesn't seem to be a way to get the first publication date :(
            //result.publishedDate = fetchResult["volumeInfo","publishedDate"].string?.toDateViaFormat("yyyy-MM-dd")

            result.hasSmallImage = fetchResult["volumeInfo", "imageLinks", "small"].string != nil
            result.hasThumbnailImage = fetchResult["volumeInfo", "imageLinks", "thumbnail"].string != nil

            // This string may contain some HTML. We want to remove them, but first we might as well replace the "<br>"s with '\n's
            // and the "<p>"s with "\n\n".
            var description = fetchResult["volumeInfo", "description"].string

            description = description?.components(separatedBy: "<br>")
                .compactMap {$0.trimming().nilIfWhitespace()}
                .joined(separator: "\n")

            description = description?.components(separatedBy: "<p>")
                .flatMap {$0.components(separatedBy: "</p>")}
                .compactMap {$0.trimming().nilIfWhitespace()}
                .joined(separator: "\n\n")

            description = description?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
            result.description = description

            // Try to get the categories
            if let subjects = fetchResult["volumeInfo", "categories"].array {
                result.subjects = subjects.flatMap {
                    $0.stringValue.components(separatedBy: "/").map {$0.trimming()}
                }.filter { $0 != "General" }.distinct()
            }

            return result
        }
    }

    enum GoogleErrorType: Error {
        case noResult
    }

    class GoogleError: Error {
        let code: Int
        let message: String

        init(code: Int, message: String) {
            self.code = code
            self.message = message
        }
    }

    class SearchResult {
        let id: String
        var title: String
        var authors: [String]
        var isbn13: String?
        var thumbnailCoverUrl: URL?

        init(id: String, title: String, authors: [String]) {
            self.id = id
            self.title = title
            self.authors = authors
        }
    }

    class FetchResult {
        let id: String
        var title: String
        var authors = [String]()
        var isbn13: String?
        var description: String?
        var subjects = [String]()
        var publishedDate: Date?
        var pageCount: Int?
        var hasThumbnailImage: Bool = false
        var hasSmallImage: Bool = false

        var coverImage: Data?

        init(fromSearchResult searchResult: SearchResult) {
            id = searchResult.id
            title = searchResult.title
            authors = searchResult.authors
            isbn13 = searchResult.isbn13
        }
    }

    class SearchResultsPage {
        let searchResults: Result<[SearchResult]>
        let searchText: String?

        init(_ results: Result<[SearchResult]>, fromSearchText searchText: String?) {
            self.searchText = searchText
            self.searchResults = results
        }

        convenience init(_ results: [SearchResult], fromSearchText searchText: String) {
            self.init(Result.success(results), fromSearchText: searchText)
        }

        static func empty() -> SearchResultsPage {
            return SearchResultsPage(Result.success([]), fromSearchText: nil)
        }

        static func error(_ error: Error, fromSearchText searchText: String) -> SearchResultsPage {
            return SearchResultsPage(Result.failure(error), fromSearchText: searchText)
        }
    }

    class FetchResultPage {

        let request: Request
        let result: Result<FetchResult>

        init(_ result: Result<FetchResult>, fromRequest request: Request) {
            self.request = request
            self.result = result
        }

        convenience init(_ result: FetchResult, fromRequest request: Request) {
            self.init(Result.success(result), fromRequest: request)
        }

        static func empty(fromRequest request: Request) -> FetchResultPage {
            return FetchResultPage(Result.failure(GoogleErrorType.noResult), fromRequest: request)
        }

        static func error(_ error: Error, fromRequest request: Request) -> FetchResultPage {
            return FetchResultPage(Result.failure(error), fromRequest: request)
        }
    }
}
