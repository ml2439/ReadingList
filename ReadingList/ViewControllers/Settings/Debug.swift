#if DEBUG
    
import Foundation
import Eureka
import SVProgressHUD
import SimulatorStatusMagic

class Debug: FormViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        form +++ Section(header: "Test data", footer: "Import a set of data for both testing and screenshots")
            <<< ButtonRow() {
                $0.title = "Import Test Data"
                $0.onCellSelection { _,_ in
                    Debug.loadTestData()
                }
            }
        
        form +++ SelectableSection<ListCheckRow<BarcodeScanSimulation>>("Barcode scan behaviour", selectionType: .singleSelection(enableDeselection: false)) {
            let currentValue = DebugSettings.barcodeScanSimulation
            for option: BarcodeScanSimulation in [.none, .normal, .noCameraPermissions, .validIsbn, .unfoundIsbn, .existingIsbn] {
                $0 <<< ListCheckRow<BarcodeScanSimulation>(){
                    $0.title = option.titleText
                    $0.selectableValue = option
                    $0.value = (option == currentValue ? option : nil)
                    $0.onChange{
                        DebugSettings.barcodeScanSimulation = $0.value ?? .none
                    }
                }
            }
        }
        
        form +++ SelectableSection<ListCheckRow<QuickAction>>("Quick Action Simulation", selectionType: .singleSelection(enableDeselection: false)) {
            let currentQuickActionValue = DebugSettings.quickActionSimulation
            for quickActionOption: QuickAction in [.none, .barcodeScan, .searchOnline] {
                $0 <<< ListCheckRow<QuickAction>(){
                    $0.title = quickActionOption.titleText
                    $0.selectableValue = quickActionOption
                    $0.value = (quickActionOption == currentQuickActionValue ? quickActionOption : nil)
                    $0.onChange{
                        DebugSettings.quickActionSimulation = $0.value ?? .none
                    }
                }
            }
        }
        
        form +++ Section("Debug Controls")
            <<< SwitchRow() {
                $0.title = "Show sort number"
                $0.value = DebugSettings.showSortNumber
                $0.onChange {
                    DebugSettings.showSortNumber = $0.value ?? false
                }
            }
            <<< SwitchRow() {
                $0.title = "Show cell reload control"
                $0.value = DebugSettings.showCellReloadControl
                $0.onChange {
                    DebugSettings.showCellReloadControl = $0.value ?? false
                }
        }
    }
    
    static func loadTestData(withLists: Bool = true) {
        
        appDelegate.booksStore.deleteAll()
        let csvPath = Bundle.main.url(forResource: "examplebooks", withExtension: "csv")
        
        SVProgressHUD.show(withStatus: "Loading Data...")
        
        BookImporter(csvFileUrl: csvPath!, supplementBookCover: true, missingHeadersCallback: {
            print("Missing headers!")
        }, supplementBookCallback: { book, _ in
            // Extra supplementary details
            if book.title == "Your First Swift App" {
                book.coverImage = UIImagePNGRepresentation(#imageLiteral(resourceName: "yourfirstswiftapp.png"))
            }
        }) { _, _, _ in
            appDelegate.booksStore.deleteAllLists()
            SVProgressHUD.dismiss()
        }.StartImport()
    }    
}

#endif
