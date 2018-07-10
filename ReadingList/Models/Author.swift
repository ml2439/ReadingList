import Foundation
import CoreData

@objc(Author)
public class Author: NSObject, NSCoding {
    
    let lastName: String
    let firstNames: String?
    
    init(lastName: String, firstNames: String?) {
        self.lastName = lastName
        self.firstNames = firstNames
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        let lastName = aDecoder.decodeObject(forKey: "lastName") as! String
        let firstNames = aDecoder.decodeObject(forKey: "firstNames") as! String?
        self.init(lastName: lastName, firstNames: firstNames)
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.lastName, forKey: "lastName")
        aCoder.encode(self.firstNames, forKey: "firstNames")
    }
    
    var displayFirstLast: String {
        return (firstNames == nil ? "" : "\(firstNames!) ") + lastName
    }
    
    var displayLastCommaFirst: String {
        return lastName + (firstNames == nil ? "" : ", \(firstNames!)")
    }
    
    static func authorSort(_ authors: [Author]) -> String {
        return authors.map {
            [$0.lastName, $0.firstNames].compactMap { $0?.sortable }.joined(separator: ".")
            }.joined(separator: "..")
    }
    
    static func authorDisplay(_ authors: [Author]) -> String {
        return authors.map { $0.displayFirstLast }.joined(separator: ", ")
    }
}
