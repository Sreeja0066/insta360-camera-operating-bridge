//
//  MediasViewController.swift
//  INSCameraSDKSample-osc
//
//  Created by HkwKelvin on 2018/11/1.
//  Copyright © 2018年 insta360. All rights reserved.
//

import UIKit

import Eureka
import INSCameraSDK

class MediasViewController: FormViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        form
            +++ mediasSection
    }
    
    var mediasSection: Section {
        let section = Section()
        section
            <<< ButtonRow("Generate HDR photo") { row in
                row.title = row.tag;
                }.onCellSelection({ [weak self] (_, row) in
                    print("Generate HDR photo")
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let options: INSHDROptions = INSHDROptions()
                    options.urls = strongSelf.fileURLs()
                    options.seamlessType = INSSeamlessType.opticalFlow
                    
                    let commandManager = INSCameraManager.shared().commandManager
                    let task: INSHDRTask = INSHDRTask(commandManager: commandManager)
                    task.process(with: options, completion: { (err, data) in
                        if let err = err {
                            print("\(row.title!) failed with error: \(err)")
                            strongSelf.showAlert(row.title!, err.localizedDescription)
                            return
                        }
                        
                        // do anything with the stitched image here, for example, display it
                        if let hdrData = data, let hdrImage = UIImage(data: hdrData) {
                            strongSelf.displayImage(hdrImage, duration: 5)
                        }
                    })
                    
                })
            <<< ButtonRow("HDR Mat rgb data") { row in
                row.title = row.tag;
                }.onCellSelection({ [weak self] (_, row) in
                    print("Generate HDR photo")
                    guard let strongSelf = self else {
                        return
                    }

                    let commandManager = INSCameraManager.shared().commandManager
                    let task: INSHDRTask = INSHDRTask(commandManager: commandManager)
                    task.process(with: strongSelf.fileURLs(), seamlessType: INSSeamlessType.opticalFlow, completion: { (err, dataModel) in
                        if let err = err {
                            print("\(row.title!) failed with error: \(err)")
                            strongSelf.showAlert(row.title!, err.localizedDescription)
                            return
                        }
                        
                        // do anything with the HDR Mat rgb data, for example, stitched image here
                        if let documentPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,FileManager.SearchPathDomainMask.userDomainMask,true).last {
                            let url: URL = URL(fileURLWithPath: documentPath).appendingPathComponent("test")
                            do {
                                try dataModel?.data?.write(to: url)
                                print("Save HDR Mat rgb data success")
                                strongSelf.showAlert(row.title!, "Save HDR Mat rgb data success")
                            }
                            catch let error {
                                print("Generate HDR error: \(error)")
                                strongSelf.showAlert(row.title!, "Generate HDR error: \(error)")
                            }
                        }
                    })
                })
            <<< ButtonRow("Local thumbnail") { row in
                row.title = row.tag;
                }.onCellSelection({ (_, row) in
                    DispatchQueue.global().async {
                        guard let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "jpg") else {
                            print("Render: file not found")
                            self.showAlert(row.title!, "Render: file not found");
                            return
                        }
                        let url: URL = URL(fileURLWithPath: path)
                        let parser: INSImageInfoParser = INSImageInfoParser(url: url)
                        if parser.open(), let extraInfo = parser.extraInfo {
                            guard let data = extraInfo.thumbnail else {
                                print("Render: no thumbnail")
                                self.showAlert(row.title!, "Render: no thumbnail")
                                return
                            }
                            guard let origin = UIImage(data: data) else {
                                print("Render: generate image failed")
                                self.showAlert(row.title!, "Render: generate image failed")
                                return
                            }
                            
                            let size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width / 2)
                            guard let result: UIImage = self.stitch(image: origin, extraInfo: extraInfo, outputSize: size) else { return }
                            DispatchQueue.main.async {
                                self.displayImage(result, duration: 5.0)
                            }
                        }
                    }
                })
            <<< ButtonRow("Stitch") { row in
                row.title = row.tag;
                }.onCellSelection({ (_, row) in
                    print("Stitch")
                    DispatchQueue.global().async {
                        guard let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "jpg") else {
                            print("Stitch: file not found")
                            self.showAlert(row.title!, "Stitch: file not found")
                            return
                        }
                        guard let origin = UIImage(contentsOfFile: path) else {
                            print("Stitch: generate image failed")
                            self.showAlert(row.title!, "Stitch: generate image failed")
                            return
                        }
                        let url: URL = URL(fileURLWithPath: path)
                        let parser: INSImageInfoParser = INSImageInfoParser(url: url)
                        if parser.open(), let extraInfo: INSExtraInfo = parser.extraInfo, let size = extraInfo.metadata?.fileDimension {
                            guard let result: UIImage = self.stitch(image: origin, extraInfo: extraInfo, outputSize: size) else { return }
                            DispatchQueue.main.async {
                                self.displayImage(result, duration: 5.0)
                            }
                        }
                    }
                })
            <<< ButtonRow("Internal parameters") { row in
                row.title = row.tag;
                }.onCellSelection({ (_, row) in
                    guard let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "jpg") else {
                        print("file not found")
                        self.showAlert(row.title!, "file not found")
                        return
                    }
                    let imageParser = INSImageInfoParser(url: URL(fileURLWithPath: path))
                    let image = UIImage(contentsOfFile: path)
                    if imageParser.open(), let offset = imageParser.offset {
                        let offsetParser = INSOffsetParser(offset: offset, width: Int32(image!.size.width), height: Int32(image!.size.height))
                        if let parameters = offsetParser.parameters {
                            for param in parameters {
                                print("Internal parameters: \(param)")
                                self.showAlert(row.title!, "Internal parameters: \(param)")
                            }
                        }
                    }
                })
        return section
    }

    func fileURLs() -> [URL] {
        // ./Documents/HDR/...
        guard let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
            let subPaths = try? FileManager.default.subpathsOfDirectory(atPath: "\(documentPath)/HDR"), subPaths.count > 0 else {

            let names: [String] = ["IMG_20181029_182547_00_295", "IMG_20181029_182547_00_296", "IMG_20181029_182547_00_297"]
            var urls: [URL] = [URL]()
            for name in names {
                let path: String = Bundle.main.path(forResource: name, ofType: "jpg")!
                let url: URL = URL(fileURLWithPath: path)
                urls.append(url)
            }
            return urls
        }
        
        // [ev0, -ev, +ev]
        var urls: [URL] = [URL]()
        for name in subPaths {
            let path: String = "\(documentPath)/HDR/\(name)"
            let url: URL = URL(fileURLWithPath: path)
            urls.append(url)
        }
        return urls
    }
}

extension MediasViewController {
    
    func stitch(image: UIImage, extraInfo: INSExtraInfo, outputSize: CGSize) -> UIImage? {
        let render: INSFlatPanoOffscreenRender = INSFlatPanoOffscreenRender(renderWidth: Int32(outputSize.width), height: Int32(outputSize.height))
        render.eulerAdjust = extraInfo.metadata?.euler
        render.offset = extraInfo.metadata?.offset
        if let gyroData = extraInfo.gyroData, let gyroPlayer = INSGyroPBPlayer(pbGyroData: gyroData) {
            let orientation = gyroPlayer.getImageOrientation(with: INSRenderType.flatPanoRender)
            render.gyroStabilityOrientation = orientation
        }
        else {
            render.gyroStabilityOrientation = GLKQuaternionIdentity
        }
        render.setRenderImage(image)
        return render.renderToImage()
    }
    
    func displayImage(_ image: UIImage, duration: Double) {
        let imageView = UIImageView.init(frame: CGRect(x: 0, y: 400, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width / 2))
        imageView.image = image
        self.view.addSubview(imageView)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
            imageView.removeFromSuperview()
        })
    }
}
