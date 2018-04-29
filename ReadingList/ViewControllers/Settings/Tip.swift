import SwiftyStoreKit
import StoreKit

class Tip: UIViewController, ThemeableViewController {
    static let smallTipId = "smalltip"
    static let mediumTipId = "mediumtip"
    static let largeTipId = "largetip"
    var tipProducts: Set<SKProduct>?

    @IBOutlet private weak var explanationLabel: UILabel!

    // Small and large tip buttons are hidden at load
    @IBOutlet private weak var smallTip: UIButton!
    @IBOutlet private weak var mediumTip: UIButton!
    @IBOutlet private weak var largeTip: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        SwiftyStoreKit.retrieveProductsInfo([Tip.smallTipId, Tip.mediumTipId, Tip.largeTipId]) { [weak self] results in
            guard let viewController = self else { return }
            guard results.retrievedProducts.count == 3 else {
                viewController.mediumTip.isEnabled = false
                viewController.mediumTip.setTitle("Not available", for: .normal)
                return
            }
            viewController.tipProducts = results.retrievedProducts
            viewController.displayTipPrices()
        }

        monitorThemeSetting()
    }

    func displayTipPrices() {
        guard let tipProducts = tipProducts else { return }

        let priceFormatter = NumberFormatter()
        priceFormatter.formatterBehavior = .behavior10_4
        priceFormatter.numberStyle = .currency
        priceFormatter.locale = tipProducts.first!.priceLocale

        for product in tipProducts {
            guard let priceString = priceFormatter.string(from: product.price) else { continue }
            let button: UIButton
            switch product.productIdentifier {
            case Tip.smallTipId: button = smallTip
            case Tip.mediumTipId: button = mediumTip
            case Tip.largeTipId: button = largeTip
            default: continue
            }

            button.isHidden = false
            button.isEnabled = true
            button.setTitle(priceString, for: .normal)
        }
    }

    @IBAction private func tipPressed(_ sender: UIButton) {
        guard let tipProducts = tipProducts else { return }

        let productId: String
        if sender == smallTip {
            productId = Tip.smallTipId
        } else if sender == mediumTip {
            productId = Tip.mediumTipId
        } else if sender == largeTip {
            productId = Tip.largeTipId
        } else {
            return
        }

        guard let product = tipProducts.first(where: { $0.productIdentifier == productId }) else { return }

        SwiftyStoreKit.purchaseProduct(product) { [weak self] result in
            switch result {
            case .success:
                guard let viewController = self else { return }
                viewController.explanationLabel.text = "Thanks for supporting Reading List! ❤️"
                viewController.smallTip.isHidden = true
                viewController.mediumTip.isHidden = true
                viewController.largeTip.isHidden = true
                UserSettings.hasEverTipped.value = true

            case .error(let error):
                guard error.code != .paymentCancelled else { return }

                let alert = UIAlertController(title: "Tip Failed", message: "Something went wrong - thanks for trying though!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default))
                appDelegate.window?.rootViewController?.present(alert, animated: true)
            }
        }
    }

    func initialise(withTheme theme: Theme) {
        view.backgroundColor = theme.viewBackgroundColor
        explanationLabel.textColor = theme.titleTextColor
    }
}
