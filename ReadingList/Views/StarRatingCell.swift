import Foundation
import UIKit
import Eureka

public class StarRatingCell: Cell<Int>, CellType {

    @IBOutlet private weak var stackView: UIStackView!

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
            if let starRating = row.value, starRating >= button.tag {
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
        if row.value == tappedRating {
            row.value = nil
        } else {
            row.value = tappedRating
        }
        update()
    }
}

public final class StarRatingRow: Row<StarRatingCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
        cellProvider = CellProvider<StarRatingCell>(nibName: "StarRatingCell")
    }
}
