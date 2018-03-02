import Foundation
import UIKit
import SVProgressHUD
import Fabric
import Crashlytics
import CoreData

class DataVC: UITableViewController, UIDocumentPickerDelegate, UIDocumentMenuDelegate {
    
    static let importIndexPath = IndexPath(row: 0, section: 1)
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            exportData()
        case (DataVC.importIndexPath.section, DataVC.importIndexPath.row):
            requestImport()
        case (2, 0):
            deleteAllData()
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func requestImport() {
        let documentImport = UIDocumentMenuViewController(documentTypes: ["public.comma-separated-values-text"], in: .import)
        documentImport.delegate = self
        if let popPresenter = documentImport.popoverPresentationController {
            let cell = tableView(tableView, cellForRowAt: DataVC.importIndexPath)
            popPresenter.sourceRect = cell.frame
            popPresenter.sourceView = self.tableView
            popPresenter.permittedArrowDirections = .up
        }
        present(documentImport, animated: true)
    }
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        SVProgressHUD.show(withStatus: "Importing")
        UserEngagement.logEvent(.csvImport)
        
        BookCSVImporter().startImport(fromFileAt: url) { results in
            var statusMessage = "\(results.success) books imported."
            
            if results.duplicate != 0 { statusMessage += " \(results.duplicate) rows ignored due pre-existing data." }
            if results.error != 0 { statusMessage += " \(results.error) rows ignored due to invalid data." }
            SVProgressHUD.showInfo(withStatus: statusMessage)
        }
    }
    
    func exportData() {
        UserEngagement.logEvent(.csvExport)
        SVProgressHUD.show(withStatus: "Generating...")
        
        let listNames = List.names(fromContext: PersistentStoreManager.container.viewContext)
        let exporter = CsvExporter(csvExport: Book.BuildCsvExport(withLists: listNames))
        
        let exportAll = NSManagedObject.fetchRequest(Book.self)
        exportAll.sortDescriptors = [NSSortDescriptor(\Book.readState), NSSortDescriptor(\Book.sort), NSSortDescriptor(\Book.startedReading), NSSortDescriptor(\Book.finishedReading)]
        try! PersistentStoreManager.container.viewContext.execute(NSAsynchronousFetchRequest(fetchRequest: exportAll) {
            exporter.addData($0.finalResult ?? [])
            self.renderAndServeCsvExport(exporter)
        })
    }
    
    func renderAndServeCsvExport(_ exporter: CsvExporter<Book>) {
        DispatchQueue.global(qos: .userInitiated).async {
            
            // Write the document to a temporary file
            let exportFileName = "Reading List - \(UIDevice.current.name) - \(Date().string(withDateFormat: "yyyy-MM-dd hh-mm")).csv"
            let temporaryFilePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(exportFileName)
            do {
                try exporter.write(to: temporaryFilePath)
            }
            catch {
                Crashlytics.sharedInstance().recordError(error)
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    SVProgressHUD.showError(withStatus: "Error exporting data.")
                }
                return
            }

            
            // Present a dialog with the resulting file
            let activityViewController = UIActivityViewController(activityItems: [temporaryFilePath], applicationActivities: [])
            activityViewController.excludedActivityTypes = [
                UIActivityType.addToReadingList,
                UIActivityType.assignToContact, UIActivityType.saveToCameraRoll, UIActivityType.postToFlickr, UIActivityType.postToVimeo,
                UIActivityType.postToTencentWeibo, UIActivityType.postToTwitter, UIActivityType.postToFacebook, UIActivityType.openInIBooks
            ]
            
            if let popPresenter = activityViewController.popoverPresentationController {
                let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0))!
                popPresenter.sourceRect = cell.frame
                popPresenter.sourceView = self.tableView
                popPresenter.permittedArrowDirections = .any
            }
            
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                self.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
    func deleteAllData() {
        
        // The CONFIRM DELETE action:
        let confirmDelete = UIAlertController(title: "Final Warning", message: "This action is irreversible. Are you sure you want to continue?", preferredStyle: .alert)
        confirmDelete.addAction(UIAlertAction(title: "Delete", style: .destructive) { [unowned self] _ in
            self.deleteAll()
            UserEngagement.logEvent(.deleteAllData)
        })
        confirmDelete.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // The initial WARNING action
        let areYouSure = UIAlertController(title: "Warning", message: "This will delete all books saved in the application. Are you sure you want to continue?", preferredStyle: .alert)
        areYouSure.addAction(UIAlertAction(title: "Delete", style: .destructive) { [unowned self] _ in
            self.present(confirmDelete, animated: true)
        })
        areYouSure.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(areYouSure, animated: true)
    }
    
    func deleteAll() {
    
        let deleteContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        deleteContext.parent = PersistentStoreManager.container.viewContext
        deleteContext.automaticallyMergesChangesFromParent = true
        
        let batchDeleteLists = NSBatchDeleteRequest(fetchRequest: List.fetchRequest())
        try! PersistentStoreManager.container.persistentStoreCoordinator.execute(batchDeleteLists, with: deleteContext)
        let batchDeleteBooks = NSBatchDeleteRequest(fetchRequest: Book.fetchRequest())
        try! PersistentStoreManager.container.persistentStoreCoordinator.execute(batchDeleteBooks, with: deleteContext)
        
        NotificationCenter.default.post(name: Notification.Name.PersistentStoreBatchOperationOccurred, object: nil)
    }
}

extension Notification.Name {
    static let PersistentStoreBatchOperationOccurred = Notification.Name("persistent-store-batch-operation-occurred")
}
