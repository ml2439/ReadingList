//
//  Coffee.swift
//  books
//
//  Created by Andrew Bennet on 12/12/2017.
//  Copyright © 2017 Andrew Bennet. All rights reserved.
//

import SwiftyStoreKit
import StoreKit

class Tip: UIViewController {
    static let smallTipId = "smalltip"
    static let mediumTipId = "mediumtip"
    static let largeTipId = "largetip"
    var tipProducts: Set<SKProduct>?
    
    @IBOutlet weak var explanationLabel: UILabel!

    // Small and large tip buttons are hidden at load
    @IBOutlet weak var smallTip: UIButton!
    @IBOutlet weak var mediumTip: UIButton!
    @IBOutlet weak var largeTip: UIButton!
    
    override func viewDidLoad() {
        SwiftyStoreKit.retrieveProductsInfo([Tip.smallTipId, Tip.mediumTipId, Tip.largeTipId]){ [weak self] results in
            guard let vc = self else { return }
            guard results.retrievedProducts.count == 3 else {
                vc.mediumTip.isEnabled = false
                vc.mediumTip.setTitle("Not available", for: .normal)
                return
            }
            vc.tipProducts = results.retrievedProducts
            vc.displayTipPrices()
        }
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
    
    @IBAction func tipPressed(_ sender: UIButton) {
        guard let tipProducts = tipProducts else { return }
        
        let productId: String
        if sender == smallTip { productId = Tip.smallTipId }
        else if sender == mediumTip { productId = Tip.mediumTipId }
        else if sender == largeTip { productId = Tip.largeTipId }
        else { return }
        
        guard let product = tipProducts.first(where: {$0.productIdentifier == productId}) else { return }
        
        SwiftyStoreKit.purchaseProduct(product) { [weak self] result in
            switch result {
            case .success:
                guard let vc = self else { return }
                vc.explanationLabel.text = "Thanks for supporting Reading List! ❤️"
                vc.smallTip.isHidden = true
                vc.mediumTip.isHidden = true
                vc.largeTip.isHidden = true
                UserSettings.hasEverTipped.value = true
            
            case .error(let error):
                guard error.code != .paymentCancelled else { return }
                
                let alert = UIAlertController(title: "Tip Failed", message: "Something went wrong - thanks for trying though!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default))
                appDelegate.window?.rootViewController?.present(alert, animated: true)
            }
        }
    }
}
