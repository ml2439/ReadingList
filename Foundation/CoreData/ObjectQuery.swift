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
    
    func filtered(predicate: NSPredicate) -> ObjectQuery<T> {
        return self.with(predicate: predicate)
    }
    
    func filtered<Value>(_ keyPath: KeyPath<T, Value>, _ comparison: PredicateComparison, _ comparisonValue: Value) -> ObjectQuery<T> {
        return self.with(predicate: NSPredicate(keyPath, comparison, comparisonValue))
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
    
    func fetchController<Value>(sectionKeyPath: KeyPath<T, Value>, context: NSManagedObjectContext) -> NSFetchedResultsController<T> {
        return fetchController(sectionKeyPath: sectionKeyPath.string, context: context)
    }

    func fetchController(context: NSManagedObjectContext) -> NSFetchedResultsController<T> {
        return fetchController(sectionKeyPath: nil, context: context)
    }
    
    private func fetchController(sectionKeyPath: String?, context: NSManagedObjectContext) -> NSFetchedResultsController<T> {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = sortDescriptors
        // TODO: Set batch size?
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: sectionKeyPath, cacheName: nil)
    }
}

extension NSPredicate {
    convenience init<T, Value>(_ keyPath: KeyPath<T, Value>, _ comparison: PredicateComparison, _ comparisonValue: Value) {
        self.init(format: "%K \(comparison.rawValue) %@", argumentArray: [keyPath.string, comparisonValue])
    }
}

extension KeyPath {
    var string: String {
        get {
            // This is a bit dodgy. If this ever stops working for a future version of Swift, and there is no workaround,
            // the filtered function should just accept a String keypath and the callers should use #keyPath(_) instead.
            return self._kvcKeyPathString!
        }
    }
}

enum PredicateComparison: String {
    case equals = "=="
    case lessThan = "<"
    case greaterThan = ">"
    case lessThanEqual = "<="
    case greaterThanEqual = ">="
    case containsCaseInsensitive = "CONTAINS[cd]"
}

