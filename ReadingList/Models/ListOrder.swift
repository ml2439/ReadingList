import Foundation

@objc enum ListOrder: Int16, CaseIterable, CustomStringConvertible {
    case custom = 0
    case title = 1
    case author = 2
    case started = 3
    case finished = 4

    var description: String {
        switch self {
        case .custom: return "Custom"
        case .author: return "Author"
        case .title: return "Title"
        case .started: return "Date Started"
        case .finished: return "Date Finished"
        }
    }

    var sortDescriptors: [NSSortDescriptor]? {
        switch self {
        case .title: return [NSSortDescriptor(\Book.title)]
        case .author: return [NSSortDescriptor(\Book.authorSort), NSSortDescriptor(\Book.title)]
        case .started: return [NSSortDescriptor(\Book.startedReading, ascending: false), NSSortDescriptor(\Book.title)]
        case .finished: return [NSSortDescriptor(\Book.finishedReading, ascending: false),
                                NSSortDescriptor(\Book.startedReading, ascending: false),
                                NSSortDescriptor(\Book.title)]
        case .custom: return nil
        }
    }
}
