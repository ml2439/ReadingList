import Foundation
import UIKit

class BookTableViewCell: UITableViewCell, ThemeableView {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorsLabel: UILabel!
    @IBOutlet weak var bookCover: UIImageView!
    @IBOutlet weak var readTimeLabel: UILabel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initialise(withTheme: UserSettings.theme)
    }
    
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        titleLabel.textColor = theme.titleTextColor
        authorsLabel.textColor = theme.subtitleTextColor
        readTimeLabel?.textColor = theme.subtitleTextColor
    }
    
    func configureFrom(_ book: Book) {
        titleLabel.text = book.title
        authorsLabel.text = book.authorDisplay
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
                titleLabel.text =  "(\(book.sort?.intValue.string ?? "none")) \(book.title)"
            }
        #endif
    }
}
