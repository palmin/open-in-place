//
//  AppDelegate.swift
//  OpenInPlace
//
//  Created by Anders Borum on 21/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        XCallbackOpener.shared.openCallback = { url, vc in
            let split = vc as? UISplitViewController
            let nav = split?.viewControllers.first as? UINavigationController
            let list = nav?.viewControllers.first as? ListController
            list?.addURL(url)
        }
        
        return true
    }
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
    }
}
