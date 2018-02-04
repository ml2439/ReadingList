//
//  NavigationControllerWithReadState.swift
//  books
//
//  Created by Andrew Bennet on 01/05/2016.
//  Copyright © 2016 Andrew Bennet. All rights reserved.
//

import UIKit
import Eureka

class PreviewingNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        return self.topViewController!.previewActionItems
    }
}

extension UIViewController {
    func sizeClass() -> (UIUserInterfaceSizeClass, UIUserInterfaceSizeClass) {
        return (self.traitCollection.horizontalSizeClass, self.traitCollection.verticalSizeClass)
    }
}


class HairlineConstraint: NSLayoutConstraint {
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.constant = 1.0 / UIScreen.main.scale
    }
}

@IBDesignable
class BorderedButton: UIButton {
    @IBInspectable var cornerRadius: CGFloat = 12
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = cornerRadius
        layer.borderWidth = 0
        setTitleColor(UIColor.white, for: state)
        setColor(tintColor)
    }
    
    func setColor(_ colour: UIColor) {
        backgroundColor = colour
    }
    
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        awakeFromNib()
    }
}

extension UIBarButtonItem {
    func toggleHidden(hidden: Bool) {
        isEnabled = !hidden
        tintColor = hidden ? UIColor.clear : nil
    }
}

class NavRow<T: UIViewController> : Row<ButtonCellOf<String>> {
    var presentationMode: PresentationMode<UIViewController>
    
    init(title: String, embedInNav: Bool = true) {
        presentationMode = PresentationMode.show(controllerProvider: ControllerProvider.callback(builder: {
            let vc = T()
            vc.navigationItem.title = title
            return embedInNav ? UINavigationController(rootViewController: vc) : vc
        }), onDismiss: nil)
        super.init(tag: nil)
        displayValueFor = nil
        cellStyle = .default
        self.title = title
    }
    
    required init(tag: String?) {
        presentationMode = PresentationMode.show(controllerProvider: ControllerProvider.callback(builder: { return T() }), onDismiss: nil)
        super.init(tag: tag)
        displayValueFor = nil
        cellStyle = .default
    }
    
    open override func customDidSelect() {
        super.customDidSelect()
        guard !isDisabled else { return }
        if let controller = presentationMode.makeController() {
            presentationMode.present(controller, row: self, presentingController: self.cell.formViewController()!)
        }
    }
    
    open override func customUpdateCell() {
        super.customUpdateCell()
        cell.textLabel?.textAlignment = .left
        cell.textLabel?.textColor = .black
        cell.accessoryType = .disclosureIndicator
    }
    
    open override func prepare(for segue: UIStoryboardSegue) {
        super.prepare(for: segue)
        (segue.destination as? RowControllerType)?.onDismissCallback = presentationMode.onDismissCallback
    }
}

func NavigationRow(title: String, segueName: String, initialiser: ((ButtonRow) -> Void)? = nil, updater: ((ButtonCellOf<String>, ButtonRow) -> Void)? = nil) -> ButtonRow {
    return ButtonRow() {
        $0.title = title
        $0.presentationMode = .segueName(segueName: segueName, onDismiss: nil)
        initialiser?($0)
        }.cellUpdate{ cell, row in
            cell.textLabel?.textAlignment = .left
            cell.textLabel?.textColor = .black
            cell.accessoryType = .disclosureIndicator
            updater?(cell, row)
    }
}

func ActionButton(title: String, action: @escaping () -> Void, updater: ((ButtonCellOf<String>, ButtonRow) -> Void)? = nil) -> ButtonRow {
    return ButtonRow() {
        $0.title = title
        }.cellUpdate{ cell, row in
            cell.textLabel?.textAlignment = .left
            updater?(cell, row)
        }.onCellSelection{_,_ in
            action()
    }
}

func ActionButton(title: String, updater: ((ButtonCellOf<String>, ButtonRow) -> Void)? = nil, url: URL) -> ButtonRow {
    return ActionButton(title: title, action: {UIApplication.shared.openUrlPlatformSpecific(url: url)}, updater: updater)
}

extension UILabel {
    var isTruncated: Bool {
        guard let labelText = text else { return false }
        let labelTextSize = (labelText as NSString).boundingRect(
            with: CGSize(width: frame.size.width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [NSAttributedStringKey.font: font],
            context: nil).size
        return labelTextSize.height > bounds.size.height
    }
}

class DynamicUILabel: UILabel {
    @IBInspectable var dynamicFontSize: String = "Title1" {
        didSet {
            font = Fonts.scaledFont(font, forTextStyle: UIFontTextStyle("UICTFontTextStyle\(dynamicFontSize)"))
        }
    }
}

@IBDesignable class RoundedImageView: UIImageView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
}

@IBDesignable class RoundedView: UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
}

class UINavigationBarLabel: UILabel {
    convenience init() {
        self.init(frame: CGRect.zero)
        backgroundColor = .clear
        textAlignment = .center
        textColor = UINavigationBar.appearance().tintColor
        font = UIFont.boldSystemFont(ofSize: 16)
    }
    
    func setTitle(_ title: String?) {
        text = title
        sizeToFit()
    }
}

extension UIScrollView {
    var universalContentInset: UIEdgeInsets {
        get {
            if #available(iOS 11.0, *) {
                return adjustedContentInset
            }
            else {
                return contentInset
            }
        }
    }
}


@IBDesignable class ClearToWhiteHorizontalGradientView: UIView {
    
    @IBInspectable var whitePosition: NSNumber = 0.4 {
        didSet {
            setupGradient()
        }
    }

    var gradient = CAGradientLayer()
    
    func setupGradient() {
        let white = UIColor.white.withAlphaComponent(1.0)
        let clear = UIColor.white.withAlphaComponent(0.0)
        gradient.colors = [clear.cgColor, white.cgColor]
        gradient.locations = [0.0, whitePosition]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.frame = bounds
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupGradient()
        layer.insertSublayer(gradient, at: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
