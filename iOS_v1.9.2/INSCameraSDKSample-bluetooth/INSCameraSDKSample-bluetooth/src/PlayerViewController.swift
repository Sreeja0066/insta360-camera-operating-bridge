//
//  PlayerViewController.swift
//  INSCameraSDK
//
//  Created by zeng bin on 5/9/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import UIKit
import INSCameraSDK
import INSCoreMedia

class PlayerViewController: UIViewController {
    
    var offset: String? = "2_743.05_745.59_769.09_0.00_0.00_90.00_746.18_2285.35_756.44_0.52_0.35_90.82_3040_1520_1026"
    var image: UIImage?
    var imageURL: URL?
    
    var pixelBuffer: CVPixelBuffer?
    var renderType = INSRenderType.sphericalPanoRender
    
    var videoURL: URL?
    var videoURL2: URL?
    var extraMetadata: INSExtraMetadata?
    
    var player = INSPlayer()
    
    // 导出
    
    var exportImage:INSExportImageSimplify?
    var exportVideo:INSExportSimplify?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        title = "player"
        
        // 添加导出按钮
        let exportButton = UIBarButtonItem(
            title: "导出",
            style: .plain,
            target: self,
            action: #selector(handleExportButtonTap)
        )
        
        navigationItem.rightBarButtonItem = exportButton
        
        // 创建播放按钮
        let playButton = UIButton(type: .system)
        playButton.setTitle("播放", for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        playButton.addTarget(self, action: #selector(handlePlayButtonTap), for: .touchUpInside)
        
        // 将播放按钮设置为导航栏的 titleView
        navigationItem.titleView = playButton
        
        if let videoURL = videoURL {
            var videoUrls : [URL] = [videoURL]
            if let url2 = videoURL2 {
                videoUrls.append(url2)
            }
            playVideoWithURLs(urls: videoUrls)
        } else if let imageURL = imageURL {
            
            let cache = NSHomeDirectory() + "/Documents/com.insta360.asset.image"
            let imageAsset = INSImageAsset(imagePath: imageURL.absoluteString, cacheDir: cache)
            
            if imageAsset.open() != nil {
                print("解析失败:\(imageURL)")
                return
            }
            
            guard let image = image else {return}
            
            if imageAsset.extraMetadata?.imageStitchType == .stitched {
                renderType = .normal
                playImagePlane(image)
                return
            } else {
                renderType = .sphericalPanoRender
                if let offsetV3 = imageAsset.extraMetadata?.offsetV3, offsetV3 != ""{
                    offset = offsetV3
                } else if let offsetV2 = imageAsset.extraMetadata?.offsetV2, offsetV2 != "" {
                    offset = offsetV2
                }else if let offsetV1 = imageAsset.extraMetadata?.offset, offsetV1 != ""{
                    offset = offsetV1
                }else{
                    print("Not parser offset message!")
                }
               
                playImage(image, offset: offset)
            }
        }
        else {
            let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "jpg")!
            let parser: INSImageInfoParser = INSImageInfoParser(url: URL(fileURLWithPath: path))
            if parser.open(), let extraInfo = parser.extraInfo {
                extraMetadata = extraInfo.metadata
                offset = parser.offset
            }
            
            if let image: UIImage = UIImage(contentsOfFile: path) {
                playImage(image, offset: offset)
            }
        }
    }
    

    
    func updateRenderSettings(render: INSRender) {
        render.offset = offset
        
        guard let extraMetadata = extraMetadata else {
            return
        }
        if let gyro = extraMetadata.thumbnailGyro {
            render.gyroAdjust = gyro
        }
    }
    
    func updateOffscreenRenderSettings(render: INSOffscreenRender) {
        render.offset = offset
        
        guard let extraMetadata = extraMetadata else {
            return
        }
        if let gyro = extraMetadata.thumbnailGyro {
            render.gyroAdjust = gyro
        }
    }
    deinit {
        previewer?.shutdown()
        exportVideo?.shutDown()
        exportVideo = nil
        exportImage = nil
    }
    
    var renderView: INSRenderView?
    var previewer: INSPreviewer3?
    
    func playVideoWithURLs(urls:[URL]) {
        let renderView = INSRenderView(frame: self.view.bounds, renderType: renderType)
        view.addSubview(renderView)
        self.renderView = renderView

        let previewer = INSPreviewer3();
        previewer.displayDelegate = renderView;
        self.previewer = previewer;

        let stitchInfo = INSStitchingInfo()
        self.renderView?.render.stitchingInfo = stitchInfo
        self.renderView?.render.colorFusion = true
        self.renderView?.render.stitchType = INSStitchType.disflow;

        var durationS: TimeInterval = 0
        var framerate: CGFloat = 0
        var offset: String? = nil
        var mediaFileSize: Int64 = 0
        var videoTrackCount: Int32 = 1
        var reverseVideoTrackOrder: Bool = false
//        let parser = INSVideoInfoParser(urls: urls);
        
        let path = urls[0].absoluteString
        print("path:\(path)")
        
        let cache = NSHomeDirectory() + "/Documents/com.insta360.asset.video"
        
        let videoAsset = INSVideoAsset(path: urls[0].absoluteString, cacheDir: cache, option: .All)
        
        if let error = videoAsset.open() {
            print("Error: \(error)")
            return
        }
        
        
        if (videoAsset.open() == nil) {
            if let offsetV3 = videoAsset.extraMetadata?.offsetV3, offsetV3 != ""{
                offset = offsetV3
            } else if let offsetV2 = videoAsset.extraMetadata?.offsetV2, offsetV2 != "" {
                offset = offsetV2
            } else if let offsetV1 = videoAsset.extraMetadata?.offset, offsetV1 != ""{
                offset = offsetV1
            } else {
                offset = self.offset
            }
          
            durationS = videoAsset.demuxerInfo?.videoDurationS ?? 0;
            framerate = videoAsset.demuxerInfo?.framerate ?? 30;
            mediaFileSize = Int64(videoAsset.mediaFileSize);
            videoTrackCount = videoAsset.extraMetadata?.videoTrackCount ?? 1;
            reverseVideoTrackOrder = videoAsset.extraMetadata?.reverseVideoTrackOrder == true;
        }
        
        let durationMs = durationS * 1000;
        
        let segment = INSEmSegment(url: urls, totalSrcDurationMs: durationMs, isValid: true)
        let videoClip = INSFileClip(emSegment: [segment], startTimeMs: 0, endTimeMs: durationMs, totalSrcDurationMs: durationMs, timeScales: nil, hasAudio: false, mediaFileSize: mediaFileSize, videoTrackCount: Int32(videoTrackCount), reverseVideoTrackOrder: reverseVideoTrackOrder)

        self.previewer?.setVideoSource([videoClip], bgmSource: nil, videoSilent: false);

        self.previewer?.prepareAsync(0);
        renderView.playVideo(withOffset: offset)
        self.previewer?.play()
    }
    
    func playImage(_ image: UIImage, offset: String?) {
        let renderView = INSRenderView(frame: self.view.bounds, renderType: renderType)
        view.addSubview(renderView)
        self.updateRenderSettings(render: renderView.render)
        renderView.play(image, offset: offset)
    }
    
    func playImagePlane(_ image: UIImage) {
        // 计算符合 2:1 宽高比的尺寸
        let parentWidth = self.view.bounds.width
        let parentHeight = self.view.bounds.height
        
        // 以高度为基准，计算宽度
        var renderHeight = parentHeight
        var renderWidth = renderHeight * 2
        
        // 如果计算出的宽度超出父视图宽度，则以宽度为基准，计算高度
        if renderWidth > parentWidth {
            renderWidth = parentWidth
            renderHeight = renderWidth / 2
        }
        
        // 创建 frame
        let renderFrame = CGRect(x: (parentWidth - renderWidth) / 2, // 居中
                                y: (parentHeight - renderHeight) / 2, // 居中
                                width: renderWidth,
                                height: renderHeight)
        
        // 创建 renderView
        let renderView = INSRenderView(frame: renderFrame, renderType: renderType)
        view.addSubview(renderView)
        
        // 设置内容缩放方式
        renderView.contentMode = .scaleAspectFit // 确保内容适应视图
        
        // 更新渲染设置
        self.updateRenderSettings(render: renderView.render)
        
        // 播放图片
        renderView.play(image, offset: nil)
    }
    
    @objc private func handlePlayButtonTap() {
        self.previewer?.seek(0.0)
        self.previewer?.play()
    }
    
    @objc private func handleExportButtonTap() {
        // 示例：同时导出所有图片和视频-
        
        self.previewer?.pause()
        
        let exportViewController = ExportVideoViewController()
        exportViewController.videoURL = videoURL;
        exportViewController.videoURL2 = videoURL2;
        exportViewController.imageURL = imageURL;
        self.show(exportViewController, sender: nil)
        
    }
    
}
