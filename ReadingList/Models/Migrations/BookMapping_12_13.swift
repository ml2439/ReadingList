import Foundation
import CoreData

class BookMapping_12_13: NSEntityMigrationPolicy { //swiftlint:disable:this type_name

    // Migrates ISBN-13 from String to Int64
    @objc func isbn(forIsbn isbn: String?) -> NSNumber? {
        guard let isbnString = isbn, let isbnInt = Int64(isbnString) else { return nil }
        return NSNumber(value: isbnInt)
    }

    // Returns the provided Google Books ID, unless that already exists in the destination context.
    // We do not expect this to ever be the case, since the UI has prevented the addition of duplicate
    // Google Book IDs, but the unique constraint did not exist in the model. This is just to ensure
    // safety.
    @objc func googleBooksId(forGoogleBooksId googleBooksId: String?, manager: NSMigrationManager) -> String? {
        guard let googleBooksId = googleBooksId else { return nil }

        let existingGoogleBooksIdRequest = NSFetchRequest<NSManagedObject>(entityName: "Book")
        existingGoogleBooksIdRequest.predicate = NSPredicate(format: "googleBooksId == %@", googleBooksId)
        existingGoogleBooksIdRequest.fetchLimit = 1
        let existingGoogleBooksIdCount = try! manager.destinationContext.count(for: existingGoogleBooksIdRequest)
        guard existingGoogleBooksIdCount == 0 else { print("*** Duplicate Google Books ID found ***"); return nil }
        return googleBooksId
    }

    // Returns the currentPage attribute if the read state is CurrentlyReading, otherwise returns nil.
    @objc func currentPage(forCurrentPage currentPage: NSNumber?, readState: Int16) -> NSNumber? {
        guard let currentPage = currentPage else { return nil }
        if readState == 1 /* BookReadState.reading = 1 */ {
            return currentPage
        } else {
            return nil
        }
    }
}
