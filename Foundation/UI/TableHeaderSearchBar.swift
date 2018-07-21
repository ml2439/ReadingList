import Foundation
import UIKit

public class TableHeaderSearchBar: UIView {

    public let searchBar: UISearchBar

    public init(searchBar: UISearchBar) {
        self.searchBar = searchBar
        super.init(frame: searchBar.frame)
        self.addSubview(searchBar)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
