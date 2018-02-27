import Foundation
import UIKit

class SearchResultCell: UITableViewCell {
    @IBOutlet weak var titleOutlet: UILabel!
    @IBOutlet weak var authorOutlet: UILabel!
    @IBOutlet weak var imageOutlet: UIImageView!
    
    private var coverImageRequest: HTTP.Request?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Cancel any pending cover data request task
        coverImageRequest?.cancel()
        
        titleOutlet.text = nil
        authorOutlet.text = nil
        imageOutlet.image = nil
    }
    
    func updateDisplay(from arrayItem: GoogleBooks.SearchResult) {
        titleOutlet.text = arrayItem.title
        authorOutlet.text = arrayItem.authors.joined(separator: ", ")
        
        guard let coverURL = arrayItem.thumbnailCoverUrl else { imageOutlet.image = #imageLiteral(resourceName: "CoverPlaceholder"); return }
        coverImageRequest = HTTP.Request.get(url: coverURL).data { [weak self] result in
            // Cancellations appear to be reported as errors. Ideally we would detect non-cancellation
            // errors (e.g. 404), and show the placeholder in those cases. For now, just make the image blank.
            guard result.isSuccess, let data = result.value else { self?.imageOutlet.image = nil; return }
            self?.imageOutlet.image = UIImage(data: data)
        }
    }
}
