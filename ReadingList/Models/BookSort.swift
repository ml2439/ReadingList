import Foundation
import ReadingList_Foundation

@objc enum BookSort: Int16, CaseIterable, CustomStringConvertible, UserSettingType {
    case custom = 1
    case startDate = 2
    case finishDate = 3
    case title = 4
    case author = 5

    var description: String {
        switch self {
        case .custom: return "Custom"
        case .startDate: return "Start Date"
        case .finishDate: return "Finish Date"
        case .title: return "Title"
        case .author: return "Author"
        }
    }

    var canSortLists: Bool {
        return true
    }

    func canSortBooks(ofState state: BookReadState) -> Bool {
        switch state {
        case .toRead: return [BookSort.custom, .title, .author].contains(self)
        case .reading: return [BookSort.custom, .startDate, .title, .author].contains(self)
        case .finished: return [BookSort.custom, .startDate, .finishDate, .title, .author].contains(self)
        }
    }

    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .title: return [NSSortDescriptor(\Book.title)]
        case .author: return [NSSortDescriptor(\Book.authorSort),
                              NSSortDescriptor(\Book.title)]
        case .startDate: return [NSSortDescriptor(\Book.startedReading, ascending: false),
                                 NSSortDescriptor(\Book.title)]
        case .finishDate: return [NSSortDescriptor(\Book.finishedReading, ascending: false),
                                  NSSortDescriptor(\Book.startedReading, ascending: false),
                                  NSSortDescriptor(\Book.title)]
        case .custom: return [NSSortDescriptor(Book.Key.sort.rawValue),
                              NSSortDescriptor(\Book.googleBooksId),
                              NSSortDescriptor(\Book.manualBookId)]
        }
    }
}
