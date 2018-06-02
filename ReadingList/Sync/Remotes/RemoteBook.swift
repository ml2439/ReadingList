import Foundation

class RemoteBook: RemoteRecord {
    var id: RemoteRecordID?
    var creatorID: RemoteRecordID?
    var googleBooksId: String?

    init(book: Book) {
        googleBooksId = book.googleBooksId
    }
}
