import Foundation
import ReadingList_Foundation

enum TableSortOrder: Int, UserSettingType {
    case customOrder = 1
    case byStartDate = 2
    case byFinishDate = 3
    case byTitle = 4
    case byAuthor = 5

    var displayName: String {
        switch self {
        case .customOrder: return "Custom"
        case .byStartDate: return "By Start Date"
        case .byFinishDate: return "By Finish Date"
        case .byTitle: return "By Title"
        case .byAuthor: return "By Author"
        }
    }

    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .byTitle:
            return [NSSortDescriptor(\Book.title)]
        case .byAuthor:
            return [NSSortDescriptor(\Book.authorSort), NSSortDescriptor(\Book.title)]
        case .byStartDate:
            return [NSSortDescriptor(\Book.startedReading, ascending: false)]
        case .byFinishDate:
            return [NSSortDescriptor(\Book.finishedReading, ascending: false), NSSortDescriptor(\Book.startedReading, ascending: false)]
        case .customOrder:
            return [NSSortDescriptor(Book.Key.sort.rawValue), NSSortDescriptor(\Book.googleBooksId), NSSortDescriptor(\Book.manualBookId)]
        }
    }

    static var byReadState: [BookReadState: TableSortOrder] {
        return [
            .toRead: UserDefaults.standard[.toReadSortOrder],
            .reading: UserDefaults.standard[.readingSortOrder],
            .finished: UserDefaults.standard[.finishedSortOrder]
        ]
    }
}
