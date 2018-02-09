import Foundation
import CoreData

enum BooksModelVersion: String {
    case version5 = "books_5"
    case version6 = "books_6"
    case version7 = "books_7"
    case version8 = "books_8"
    case version9 = "books_9"
}

extension BooksModelVersion: ModelVersion {
    
    static var orderedModelVersions: [BooksModelVersion] {
        return [.version5, .version6, .version7, .version8, .version9]
    }
    
    var name: String { return rawValue }

    var modelBundle: Bundle { return Bundle(for: Book.self) }

    var modelDirectoryName: String { return "books.momd" }
    
    var successor: BooksModelVersion? {
        switch self {
        case .version5: return .version6
        case .version6: return .version7
        case .version7: return .version8
        case .version8: return .version9
        default: return nil
        }
    }
    
    func mappingModelsToSuccessor() -> [NSMappingModel]? {
        switch self {
        case .version6:
            return [mappingModelToSuccessor()!]
        default:
            let mapping = try! NSMappingModel.inferredMappingModel(forSourceModel: managedObjectModel(), destinationModel: successor!.managedObjectModel())
            return [mapping]
        }
    }
}

