import Foundation
import UIKit
import SVProgressHUD
import CoreData
import Crashlytics

class DataVC: UITableViewController {

    var importUrl: URL?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // This view can be loaded from an "Open In" action. If this happens, the importUrl property will be set.
        if let importUrl = importUrl {
            confirmImport(fromFile: importUrl)
            self.importUrl = nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0): exportData(presentingIndexPath: indexPath)
        case (1, 0): requestImport(presentingIndexPath: indexPath)
        case (2, 0): deleteAllData()
        default: break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func requestImport(presentingIndexPath: IndexPath) {
        let documentImport = UIDocumentMenuViewController(documentTypes: ["public.comma-separated-values-text"], in: .import)
        documentImport.delegate = self
        documentImport.popoverPresentationController?.setSourceCell(atIndexPath: presentingIndexPath, inTable: tableView, arrowDirections: .up)
        present(documentImport, animated: true)
    }
    
    func confirmImport(fromFile url: URL) {
        let alert = UIAlertController(title: "Confirm Import", message: "Are you sure you want to import books from this file? This will skip any rows which have an ISBN or Google Books ID which corresponds to a book already in the app; other rows will be added as new books.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Import", style: .default) { _ in
            SVProgressHUD.show(withStatus: "Importing")
            UserEngagement.logEvent(.csvImport)
            
            BookCSVImporter().startImport(fromFileAt: url) { results in
                var statusMessage = "\(results.success) books imported."
                
                if results.duplicate != 0 { statusMessage += " \(results.duplicate) rows ignored due pre-existing data." }
                if results.error != 0 { statusMessage += " \(results.error) rows ignored due to invalid data." }
                SVProgressHUD.showInfo(withStatus: statusMessage)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func exportData(presentingIndexPath: IndexPath) {
        UserEngagement.logEvent(.csvExport)
        SVProgressHUD.show(withStatus: "Generating...")
        
        let listNames = List.names(fromContext: PersistentStoreManager.container.viewContext)
        let exporter = CsvExporter(csvExport: BookCSVExport.build(withLists: listNames))
        
        // FUTURE: Should be batching the fetch and not holding the result entirely in memory
        let exportAll = NSManagedObject.fetchRequest(Book.self)
        exportAll.sortDescriptors = [NSSortDescriptor(\Book.readState), NSSortDescriptor(\Book.sort), NSSortDescriptor(\Book.startedReading), NSSortDescriptor(\Book.finishedReading)]
        try! PersistentStoreManager.container.viewContext.execute(NSAsynchronousFetchRequest(fetchRequest: exportAll) {
            exporter.addData($0.finalResult ?? [])
            self.renderAndServeCsvExport(exporter, presentingIndexPath: presentingIndexPath)
        })
    }
    
    func renderAndServeCsvExport(_ exporter: CsvExporter<Book>, presentingIndexPath: IndexPath) {
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
            activityViewController.excludedActivityTypes = UIActivityType.documentUnsuitableTypes
            activityViewController.popoverPresentationController?.setSourceCell(atIndexPath: presentingIndexPath, inTable: self.tableView)
            
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                self.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
    func deleteAllData() {
        
        // The CONFIRM DELETE action:
        let confirmDelete = UIAlertController(title: "Final Warning", message: "This action is irreversible. Are you sure you want to continue?", preferredStyle: .alert)
        confirmDelete.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            PersistentStoreManager.deleteAll()
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
}

extension DataVC: UIDocumentMenuDelegate {
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
}

extension DataVC: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        confirmImport(fromFile: url)
    }
}
