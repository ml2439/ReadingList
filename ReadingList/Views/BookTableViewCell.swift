import Foundation
import UIKit

class BookTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorsLabel: UILabel!
    @IBOutlet weak var bookCover: UIImageView!
    @IBOutlet weak var readTimeLabel: UILabel!

    private var coverImageRequest: HTTP.Request?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initialise(withTheme: UserSettings.theme)
    }
    
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        selectedBackgroundView = UIView(backgroundColor: .lightGray)
        titleLabel.textColor = theme.titleTextColor
        authorsLabel.textColor = theme.subtitleTextColor
        readTimeLabel?.textColor = theme.subtitleTextColor
    }
    
    func configureFrom(_ book: Book) {
        titleLabel.text = book.title
        authorsLabel.text = book.authorDisplay
        bookCover.image = UIImage(optionalData: book.coverImage) ?? #imageLiteral(resourceName: "CoverPlaceholder")
        if book.readState == .reading {
            readTimeLabel.text = book.startedReading!.toPrettyString()
        }
        else if book.readState == .finished {
            readTimeLabel.text = book.finishedReading!.toPrettyString()
        }
        else {
            readTimeLabel.text = nil
        }
        
        #if DEBUG
            if DebugSettings.showSortNumber {
                titleLabel.text =  "(\(book.sort?.intValue.string ?? "none")) \(book.title)"
            }
        #endif
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Cancel any pending cover data request task
        coverImageRequest?.cancel()
        
        titleLabel.text = nil
        authorsLabel.text = nil
        bookCover.image = nil
    }
    
    func configureFrom(_ searchResult: GoogleBooks.SearchResult) {
        titleLabel.text = searchResult.title
        authorsLabel.text = searchResult.authors.joined(separator: ", ")
        bookCover.image = nil
        readTimeLabel.text = nil
        
        guard let coverURL = searchResult.thumbnailCoverUrl else { bookCover.image = #imageLiteral(resourceName: "CoverPlaceholder"); return }
        coverImageRequest = HTTP.Request.get(url: coverURL).data { [weak self] result in
            // Cancellations appear to be reported as errors. Ideally we would detect non-cancellation
            // errors (e.g. 404), and show the placeholder in those cases. For now, just make the image blank.
            guard result.isSuccess, let data = result.value else { self?.bookCover.image = nil; return }
            self?.bookCover.image = UIImage(data: data)
        }
    }
}
