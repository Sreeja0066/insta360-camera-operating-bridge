//
//  AllCommandsViewController.swift
//  INSCameraSDK
//
//  Created by zeng bin on 4/13/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import Eureka
import INSCameraSDK

class AllCommandsViewController: FormViewController {
    let commandsManager = INSCameraManager.shared().commandManager;
    
    var prepareSendHeartbeats:Bool?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Commands"
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraCurrentCaptureStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
                                               name: .INSCameraRTOSState, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)),
//                                               name: .INSCameraTimelapseStatusUpdate, object: nil)
        
//        setupForm()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func handleNotification(_ notification: Notification) -> Void {
        print("receive notification \(notification.name), info: \(String(describing: notification.userInfo))");
        DispatchQueue.main.async {
            self.showAlert(notification.name.rawValue, String(describing: notification.userInfo))
        }
    }
    
    func displayImage(_ image: UIImage, duration: Double) {
        let imageView = UIImageView.init(frame: CGRect(x: 0, y: 400, width: 300, height: 150))
        imageView.image = image
        self.view.addSubview(imageView)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
            imageView.removeFromSuperview()
        })
    }
}
