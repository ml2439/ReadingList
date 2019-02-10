import Foundation
import Eureka

class SortOrder: FormViewController {

    private let customBooksToTopTag = "customBooksToTop"

    override func viewDidLoad() {
        super.viewDidLoad()

        func tableSortRow(forReadState readState: BookReadState, _ tableSort: BookSort) -> ListCheckRow<BookSort> {
            return ListCheckRow<BookSort> {
                $0.title = tableSort.description
                $0.selectableValue = tableSort
                $0.onChange {
                    guard let selectedValue = $0.value else { return }
                    UserDefaults.standard[UserSettingsCollection.sortSetting(for: readState)] = selectedValue
                    NotificationCenter.default.post(name: .BookSortOrderChanged, object: nil)
                    if let customBooksToTopRow = self.form.rowBy(tag: self.customBooksToTopTag) {
                        customBooksToTopRow.evaluateHidden()
                    }
                    UserEngagement.logEvent(.changeSortOrder)
                    UserEngagement.onReviewTrigger()
                }
                $0.value = UserDefaults.standard[UserSettingsCollection.sortSetting(for: readState)] == tableSort ? tableSort : nil
            }
        }

        // An empty section is used to add some explanation text at the top of the table
        form +++ Section(footer: """
            Set the order to be used when displaying books in each of the three sections: \
            To Read, Reading and Finished.
            """)

        +++ SelectableSection<ListCheckRow<BookSort>>(header: "Order 'To Read' By:", footer: """
                Title sorts the books alphabetically; Author sorts the books alphabetically by \
                the first author's surname; Custom allows the books to be sorted manually: tap \
                Edit and drag to reorder the books. New books can be added to either the top or \
                the bottom of the list.
                """, selectionType: .singleSelection(enableDeselection: false))
            <<< tableSortRow(forReadState: .toRead, .title)
            <<< tableSortRow(forReadState: .toRead, .author)
            <<< tableSortRow(forReadState: .toRead, .custom)
            <<< SwitchRow {
                $0.tag = self.customBooksToTopTag
                $0.title = "Add Books to Top"
                $0.value = UserDefaults.standard[.addBooksToTopOfCustom]
                $0.hidden = Condition.function([]) { _ in
                    UserDefaults.standard[.toReadSort] != .custom
                }
                $0.onChange {
                    UserDefaults.standard[.addBooksToTopOfCustom] = $0.value ?? false
                }
            }

        +++ SelectableSection<ListCheckRow<BookSort>>(header: "Order 'Reading' By:", footer: """
                Start Date orders the books with the most recently started book first.
                """, selectionType: .singleSelection(enableDeselection: false))
            <<< tableSortRow(forReadState: .reading, .startDate)
            <<< tableSortRow(forReadState: .reading, .title)
            <<< tableSortRow(forReadState: .reading, .author)

        +++ SelectableSection<ListCheckRow<BookSort>>(header: "Order 'Finished' By:", footer: """
                Finish Date orders the books with the most recently finished book first.
                """, selectionType: .singleSelection(enableDeselection: false))
            <<< tableSortRow(forReadState: .finished, .startDate)
            <<< tableSortRow(forReadState: .finished, .finishDate)
            <<< tableSortRow(forReadState: .finished, .title)
            <<< tableSortRow(forReadState: .finished, .author)

        monitorThemeSetting()
    }
}

extension Notification.Name {
    static let BookSortOrderChanged = Notification.Name("book-sort-order-changed")
}
