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
    
    func confirmImport() {
        let alert = UIAlertController(title: "Confirm import", message: "Are you sure you want to import books from this file?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default){ _ in
            
        })
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        SVProgressHUD.show(withStatus: "Importing")
        UserEngagement.logEvent(.csvImport)
        
        BookCSVImporter().startImport(fromFileAt: Bundle.main.url(forResource: "examplebooks", withExtension: "csv")!) { results in
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
}
