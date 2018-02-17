import Foundation
import UIKit

class BookTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorsLabel: UILabel!
    @IBOutlet weak var bookCover: UIImageView!
    @IBOutlet weak var readTimeLabel: UILabel?
    
    typealias ResultType = Book
    
    func configureFrom(_ book: Book) {
        titleLabel.text = book.title
        authorsLabel.text = book.authorsFirstLast
        bookCover.image = UIImage(optionalData: book.coverImage) ?? #imageLiteral(resourceName: "CoverPlaceholder")
        if book.readState == .reading {
            readTimeLabel?.text = book.startedReading!.toPrettyString()
        }
        else if book.readState == .finished {
            readTimeLabel?.text = book.finishedReading!.toPrettyString()
        }
        else {
            readTimeLabel?.text = nil
        }
        
        #if DEBUG
            if DebugSettings.showSortNumber {
                titleLabel.text =  "(\(book.sort?.string ?? "none") \(book.title)"
            }
        #endif
    }
}
