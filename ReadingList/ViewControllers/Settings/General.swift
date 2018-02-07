import Foundation
import UIKit

class General: UITableViewController {
    
    @IBOutlet weak var useLargeTitlesSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            useLargeTitlesSwitch.isOn = UserSettings.useLargeTitles.value
        }
        else {
            useLargeTitlesSwitch.isOn = false
            useLargeTitlesSwitch.isEnabled = false
        }
    }
    
    @IBAction func useLargeTitlesChanged(_ sender: UISwitch) {
        UserSettings.useLargeTitles.value = sender.isOn
    }
}
