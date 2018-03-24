import UIKit
import Foundation

enum Theme: Int {
    case normal = 1
    case dark = 2
    case black = 3
}

extension Theme {
    var keyboardAppearance: UIKeyboardAppearance {
        return self == .normal ? .default : .dark
    }
    
    var titleTextColor: UIColor {
        return self == .normal ? .black : .white
    }
    
    var subtitleTextColor: UIColor {
        return self == .normal ? .black : .white
    }
    
    var cellBackgroundColor: UIColor {
        return self == .normal ? .white : .black
    }
}

protocol ThemeableView where Self: UIView {
    func initialise(withTheme theme: Theme)
}

    protocol ThemeableViewController where Self: UIViewController {
        //func initialise(withTheme theme: Theme)
        func cascadeInitialise(withTheme theme: Theme)
    }

    /*extension ThemeableViewController {
        func cascadeInitialise(withTheme theme: Theme) {
            //initialise(withTheme: theme)
            
            //let childVCs: [UIViewController]?
            /*if let splitVC = self as? UISplitViewController {
                print("split view")
                childVCs = splitVC.viewControllers
            }
            else if let navVC = self as? UINavigationController {
                print("nav view")
                childVCs = navVC.viewControllers
            }
            else */
            
            
            if let tabVC = self as? UITabBarController, let innerVCs = tabVC.viewControllers {
                for themableVC in innerVCs.flatMap({$0 as? ThemeableViewController}) {
                    themableVC.cascadeInitialise(withTheme: theme)
                }
            }
            
            //else {
                //childVCs = nil
              //  print("no child VCs")
            //}
            
            
            //childVCs?.flatMap{$0 as? ThemeableViewController}.forEach{
              //  $0.cascadeInitialise(withTheme: theme)
            //}
        }*/


/*extension Themeable {
    func setThemeAnimated(withTheme theme: Theme) {
        UIView.transition(with: self, duration: 0.5, options: [UIViewAnimationOptions.beginFromCurrentState, UIViewAnimationOptions.transitionCrossDissolve], animations: {
            self.setTheme(theme)
        }, completion: nil)
    }
}*/

    extension UITabBarController: ThemeableViewController {
        /*func initialise(withTheme theme: Theme) {
            print("DEBUG: do nothing")//tabBar.initialise(withTheme: theme)
        }*/
        func cascadeInitialise(withTheme theme: Theme) {
            guard let viewControllers = viewControllers else { return }
            for themableVC in viewControllers.flatMap({$0 as? ThemeableViewController}) {
                themableVC.cascadeInitialise(withTheme: theme)
            }
        }
    }

extension UISplitViewController: ThemeableViewController {
    func cascadeInitialise(withTheme theme: Theme) {
        for themableVC in viewControllers.flatMap({$0 as? ThemeableViewController}) {
            themableVC.cascadeInitialise(withTheme: theme)
        }
    }
    
        /*func initialise(withTheme theme: Theme) {
            print("DEBUG: do nothing")
        }*/
    }

    /*extension UINavigationController: ThemeableViewController {
        /*func initialise(withTheme theme: Theme) {
            print("DEBUG: do nothing")/*
            navigationBar.initialise(withTheme: theme)
            if #available(iOS 11.0, *) {
                navigationItem.searchController?.searchBar.initialise(withTheme: theme)
            }*/
        }*/
    }*/

/*extension UITableViewController: ThemeableViewController {
    /*func initialise(withTheme theme: Theme) {
        print("DEBUG: do nothing")//tableView.initialise(withTheme: theme)
    }*/
}*/

extension UINavigationBar: ThemeableView {
    
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme == .dark ? .black : nil
        barTintColor = theme == .dark ? .black : nil
        titleTextAttributes = theme == .dark ? [NSAttributedStringKey.foregroundColor: UIColor.white] : nil
        if #available(iOS 11.0, *) {
            largeTitleTextAttributes = theme == .dark ? [NSAttributedStringKey.foregroundColor: UIColor.white] : nil
        }
    }
}

extension UISearchBar: ThemeableView {
    
    func initialise(withTheme theme: Theme) { keyboardAppearance = theme == .normal ? .default : .dark }
}

extension UITableView: ThemeableView {
    
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme == .normal ? .groupTableViewBackground : .veryDarkGray
        if let visibleIndexPaths = indexPathsForVisibleRows, visibleIndexPaths.count > 0 {
            reloadData()
        }
        //separatorColor = UIColor.darkGray
    }
}

extension UITabBar: ThemeableView {
    func initialise(withTheme theme: Theme) {
        barTintColor = theme == .normal ? nil : .black
    }
}
