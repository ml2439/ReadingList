import Foundation
import UIKit
import Eureka

public class StarRatingCell: Cell<Int?>, CellType {

    @IBOutlet private weak var stackView: UIStackView!

    var starRating: Int? {
        didSet {
            update()
        }
    }

    /**
     Callback used for notifying forms of a change to the selected star rating.
     The new rating is the argument.
    */
    var starRatingChanged: ((Int?) -> Void)?

    public override func setup() {
        super.setup()
        height = { return 50 }
        selectionStyle = .none
        for button in stackView.arrangedSubviews.map({ $0 as! UIButton }) {
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        }
        updateRatingDisplay()
    }

    public override func update() {
        super.update()
        updateRatingDisplay()
    }

    func updateRatingDisplay() {
        for button in stackView.arrangedSubviews.map({ $0 as! UIButton }) {
            let image: UIImage
            if let starRating = starRating, starRating >= button.tag {
                image = #imageLiteral(resourceName: "rating-star-filled")
            } else {
                image = #imageLiteral(resourceName: "rating-star")
            }
            button.setImage(image, for: .normal)
        }
    }

    @objc func buttonTapped(_ sender: UIButton) {
        let tappedRating = sender.tag

        // Star ratings are togglable. Tapping on the already selected rating will clear the rating.
        if starRating == tappedRating {
            starRating = nil
        } else {
            starRating = tappedRating
        }

        starRatingChanged?(starRating)
    }
}

public final class StarRatingRow: Row<StarRatingCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
        cellProvider = CellProvider<StarRatingCell>(nibName: "StarRatingCell")
    }

    convenience init(initialRating: Int?, onRatingChange: ((Int?) -> Void)?) {
        self.init(tag: nil)
        self.cell.starRating = initialRating
        self.cell.starRatingChanged = onRatingChange
    }
}
