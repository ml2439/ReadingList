import CoreSpotlight
import MobileCoreServices

class CoreSpotlightStack {
    
    private var domainIdentifier: String
    private var indexingAvailable: Bool
    
    init(domainIdentifier: String) {
        self.domainIdentifier = domainIdentifier
        self.indexingAvailable = CSSearchableIndex.isIndexingAvailable()
    }
    
    /**
     Adds the items to the Spotlight index.
     */
    func indexItems(_ items: [SpotlightItem]) {
        guard indexingAvailable else { return }
        CSSearchableIndex.default().indexSearchableItems(items.map{$0.toSearchableItem(domainIdentifier: self.domainIdentifier)})
    }
    
    /**
     Removes the items from the Spotlight index.
    */
    func deindexItems(_ items: [SpotlightItem]){
        guard indexingAvailable else { return }
        deindexItems(withIdentifiers: items.map{$0.uniqueIdentifier})
    }

    /**
     Removes the items from the Spotlight index.
     */
    func deindexItems(withIdentifiers identifiers: [String]){
        guard indexingAvailable else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
    }
    
    /**
     Removes **all** items from the Spotlight index.
    */
    func deindexAllItems(completionHandler: ((Error?) -> Void)? = nil) {
        guard indexingAvailable else { return }
        CSSearchableIndex.default().deleteAllSearchableItems(completionHandler: completionHandler)
    }
    
    /**
     Updates the items' entries in the Spotlight index.
    */
    func updateItems(_ items: [SpotlightItem]){
        guard indexingAvailable else { return }
        deindexItems(items)
        indexItems(items)
    }
}

class SpotlightItem {
    
    let title: String
    let description: String?
    let thumbnailImageData: Data?
    let uniqueIdentifier: String
    
    init(uniqueIdentifier: String, title: String, description: String?, thumbnailImageData: Data?){
        self.uniqueIdentifier = uniqueIdentifier
        self.title = title
        self.description = description
        self.thumbnailImageData = thumbnailImageData
    }
    
    fileprivate func toSearchableItem(domainIdentifier: String) -> CSSearchableItem {
        // Create an attribute set from the spotlight item
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attributeSet.title = title
        attributeSet.contentDescription = description
        attributeSet.thumbnailData = thumbnailImageData
        
        // Create the searchable item from the spotlight item, and set the expiry to be never
        let searchableItem = CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
        searchableItem.expirationDate = Date.distantFuture
        return searchableItem
    }
}
