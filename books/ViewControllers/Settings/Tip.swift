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
    static let tipId = "smalltip"
    var tipProduct: SKProduct?
    
    @IBOutlet weak var explanationLabel: UILabel!
    @IBOutlet weak var leaveTipButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SwiftyStoreKit.retrieveProductsInfo(Set<String>(arrayLiteral: Tip.tipId)){ [weak self] results in
            guard let vc = self else { return }
            guard let product = results.retrievedProducts.first else {
                vc.leaveTipButton.isEnabled = false
                vc.leaveTipButton.setTitle("Not available", for: .normal)
                return
            }
            
            // Set up the price label
            let priceFormatter: NumberFormatter = {
                let formatter = NumberFormatter()
                formatter.formatterBehavior = .behavior10_4
                formatter.numberStyle = .currency
                formatter.locale = product.priceLocale
                return formatter
            }()
            guard let priceString = priceFormatter.string(from: product.price) else { return }
            
            vc.tipProduct = product
            vc.leaveTipButton.isEnabled = true
            vc.leaveTipButton.setTitle(priceString, for: .normal)
        }
    }
    
    @IBAction func buyPressed(_ sender: Any) {
        guard let tipProduct = tipProduct else { return }
        SwiftyStoreKit.purchaseProduct(tipProduct) { [weak self] result in
            switch result {
            case .success:
                self?.explanationLabel.text = "Thanks for supporting Reading List! ❤️"
                self?.leaveTipButton.isHidden = true
            
            case .error(let error):
                guard error.code != .paymentCancelled else { return }
                
                let alert = UIAlertController(title: "Tip Failed", message: "Something went wrong - thanks for trying though!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default))
                appDelegate.window?.rootViewController?.present(alert, animated: true)
            }
        }
    }
}
