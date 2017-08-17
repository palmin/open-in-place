//
//  ShowError.swift
//  OpenInPlace
//
//  Created by Anders Borum on 22/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import UIKit

extension UIViewController {
    func showError(_ error : Error) {
        let alert = UIAlertController.init(title: "Error",
                                           message: error.localizedDescription,
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
