//
//  UIViewController+AlertController.swift
//  INSCameraSDK-Sample
//
//  Created by zeng bin on 5/5/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit

public extension UIViewController {
    func showAlert(_ title: String, _ message: String) {
        DispatchQueue.main.async {
            if self.presentedViewController != nil {
                self.presentedViewController!.dismiss(animated: false, completion: nil)
            }
            if self.presentingViewController != nil {
                self.presentingViewController!.dismiss(animated: false, completion: nil)
            }
            
            let preferredStyle: UIAlertController.Style = (UIDevice.current.model == "iPad") ? .alert : .actionSheet
            let alert = UIAlertController(title: title,
                                          message: message,
                                          preferredStyle: preferredStyle);
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil);
        }
    }
}
