//
//  SceneDelegate.swift
//  OpenInPlace
//
//  Created by Anders Borum on 02/01/2023.
//  Copyright © 2023 Applied Phasor. All rights reserved.
//

import UIKit

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    var split: UISplitViewController? {
        return window?.rootViewController as? UISplitViewController
    }
    
    var list : ListController? {
        guard let nav = split?.viewControllers.first as? UINavigationController,
              let list = nav.viewControllers.first as? ListController else {
            return nil
        }

        return list
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        split?.delegate = self
        
        let nav = split?.viewControllers.last as? UINavigationController
        nav?.topViewController?.navigationItem.leftBarButtonItem = split?.displayModeButtonItem
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        for context in connectionOptions.urlContexts {
            handleUrl(context.url)
        }
    }
    
    // MARK: - Open in support
    
    func handleUrl(_ url: URL) {
        if let vc = split, XCallbackOpener.shared.couldHandleUrl(url) {
            do {
                let _ = try XCallbackOpener.shared.didHandleUrl(url, vc)
            } catch {
                vc.showError(error)
            }
            return
        }

        list?.addURL(url)
    }
        
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            handleUrl(context.url)
        }
    }
    
}

extension SceneDelegate : UISplitViewControllerDelegate {
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? EditController else { return false }
        if topAsDetailController.url == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }
}

