import Foundation
import CoreData

/**
  A fluent interface which allows NSFetchRequests to be constructed with predicates and sort descriptors,
  and fetched in a single statement.
 */
class ObjectQuery<T> where T: NSManagedObject {
    
    private let predicates: [NSPredicate]
    let sortDescriptors: [NSSortDescriptor]
    
    var predicate: NSPredicate {
        get {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
    
    init(predicates: [NSPredicate]? = nil, sortDescriptors: [NSSortDescriptor]? = nil) {
        self.predicates = predicates ?? []
        self.sortDescriptors = sortDescriptors ?? []
    }
    
    private func with(predicate: NSPredicate? = nil, sortDescriptor: NSSortDescriptor? = nil) -> ObjectQuery<T> {
        let newPredicates = predicate == nil ? predicates : predicates + [predicate!]
        let newSortDescriptors = sortDescriptor == nil ? sortDescriptors : sortDescriptors + [sortDescriptor!]
        return ObjectQuery<T>(predicates: newPredicates, sortDescriptors: newSortDescriptors)
    }
    
    func filtered(_ predicate: NSPredicate) -> ObjectQuery<T> {
        return self.with(predicate: predicate)
    }
    
    func filtered(_ format: String, _ args: CVarArg...) -> ObjectQuery<T> {
        return self.with(predicate: NSPredicate(format: format, argumentArray: args))
    }
    
    func any(_ predicates: [NSPredicate]) -> ObjectQuery<T> {
        return self.with(predicate: NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
    }
    
    func sorted<Value>(_ keyPath: KeyPath<T, Value>, ascending: Bool = true) -> ObjectQuery<T> {
        return self.with(sortDescriptor: NSSortDescriptor(keyPath: keyPath, ascending: ascending))
    }
    
    func sorted(_ keyPath: String, ascending: Bool = true) -> ObjectQuery<T> {
        return self.with(sortDescriptor: NSSortDescriptor(key: keyPath, ascending: ascending))
    }
    
    func sorted(_ sortDescriptors: [NSSortDescriptor]) -> ObjectQuery<T> {
        return ObjectQuery<T>(predicates: predicates, sortDescriptors: self.sortDescriptors + sortDescriptors)
    }
    
    func fetchRequest(limit: Int? = nil) -> NSFetchRequest<T> {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        if let limit = limit { request.fetchLimit = limit }
        return request
    }
    
    // TODO: Set batch size?
    func fetch(_ count: Int? = nil, fromContext context: NSManagedObjectContext) -> [T] {
        return (try? context.fetch(fetchRequest(limit: count))) ?? []
    }
    
    func fetchAsync(fromContext context: NSManagedObjectContext, callback: @escaping ([T]) -> ()) {
        // TODO: Work out best practise for failing fetch requests
        try! context.execute(NSAsynchronousFetchRequest(fetchRequest: fetchRequest()) {
            callback($0.finalResult ?? [])
        })
    }
    
    func count(inContext context: NSManagedObjectContext) -> Int {
        return (try? context.count(for: fetchRequest())) ?? 0
    }

    func fetchController(sectionKeyPath: String? = nil, context: NSManagedObjectContext) -> NSFetchedResultsController<T> {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = sortDescriptors
        // TODO: Set batch size?
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: sectionKeyPath, cacheName: nil)
    }
}

