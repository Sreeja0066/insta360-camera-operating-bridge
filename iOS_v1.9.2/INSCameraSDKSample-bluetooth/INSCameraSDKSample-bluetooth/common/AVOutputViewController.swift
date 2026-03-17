//
//  AVOutputViewController.swift
//  INSCameraSDK-Sample
//
//  Refactored for clear logic and snapshot display
//

import UIKit
import INSCameraSDK
import INSCoreMedia

// MARK: - FPS 计数器类：用于统计帧率和播放时长
class FPSCounter {
    let interval: TimeInterval = 1   // 每秒更新一次
    private var lastCountTimestamp: TimeInterval = 0
    private var firstTimestamp: TimeInterval = 0
    private(set) var value = 0
    private(set) var fps = 0.0
    private(set) var duration = 0.0

    // 当前 FPS 和持续时间的描述文本
    var description: String {
        "FPS: \(String(format: "%.2f", fps))  Duration: \(String(format: "%.2f", duration))s"
    }

    // 重置计数器
    func reset() {
        value = 0
        lastCountTimestamp = 0
        firstTimestamp = 0
    }

    // 每帧调用一次，根据时间戳更新 FPS
    func update(with timestamp: TimeInterval) -> Bool {
        if firstTimestamp == 0 { firstTimestamp = timestamp }
        duration = timestamp - firstTimestamp
        value += 1

        guard timestamp >= lastCountTimestamp + interval else { return false }

        fps = Double(value) / (timestamp - lastCountTimestamp)
        lastCountTimestamp = timestamp
        value = 0
        return true
    }
}

// MARK: - 主控制器类：用于处理 AV 输出、控制 UI 和快照展示
class AVOutputViewController: UIViewController {

    // 画面输出组件
    var flatPanoOutput: INSCameraFlatPanoOutput?
    var screenOutput: INSCameraScreenOutput?
    var previewPlayer: INSCameraPreviewPlayer?

    // 会话对象，管理摄像头数据流和插件
    lazy var mediaSession: INSCameraMediaSession = {
        let session = INSCameraMediaSession()
        session.gyroPlayMode = .normal
        return session
    }()

    // 渲染视图，用于显示画面
    var renderView: INSRenderView?

    // UI 控件：按钮
    let previewButton = UIButton(type: .system)
    let flatPanoButton = UIButton(type: .system)
    let screenOutputButton = UIButton(type: .system)
//    let snapshotButton = UIButton(type: .system)

    // 快照图像视图
    let flatImageView = UIImageView()
    let normalImageView = UIImageView()

    // 显示帧率和时长的标签
    let flatPanoLabel = UILabel()
    let screenLabel = UILabel()

    // 帧率计数器
    let flatPanoCounter = FPSCounter()
    let screenCounter = FPSCounter()

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AV Outputs"
        view.backgroundColor = .white

        setupNotifications()
        setupUI()

        // 如果相机已连接，自动触发连接处理
        if INSCameraManager.shared().cameraState == .connected {
            onCameraConnected()
        }
    }

    deinit {
        mediaSession.stopRunning(completion: nil)
    }

    // MARK: - 设置通知监听器
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onCameraConnected), name: .INSCameraDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onCameraDisconnected), name: .INSCameraDidDisconnect, object: nil)
    }

    // MARK: - 设置 UI 布局和样式
    private func setupUI() {
        // 渲染视图（在最底层）
        let rv = INSRenderView(frame: view.bounds, renderType: .sphericalPanoRender)
        rv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(rv, at: 0)
        renderView = rv

        // 初始化各按钮
        configureButton(previewButton, title: "Preview", action: #selector(togglePreview))
        configureButton(flatPanoButton, title: "FlatPano", action: #selector(toggleFlatPano))
        configureButton(screenOutputButton, title: "ScreenOut", action: #selector(toggleScreenOut))
//        configureButton(snapshotButton, title: "Snapshot", action: #selector(takeSnapshot))

        // 标签样式
        flatPanoLabel.textColor = .darkGray
        screenLabel.textColor = .darkGray
        flatPanoLabel.font = .systemFont(ofSize: 14)
        screenLabel.font = .systemFont(ofSize: 14)

        // 快照视图样式
        for imageView in [flatImageView, normalImageView] {
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = .black
            imageView.layer.borderColor = UIColor.gray.cgColor
            imageView.layer.borderWidth = 1
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(imageView)
        }

        // 垂直按钮堆栈
        let stack = UIStackView(arrangedSubviews: [
            previewButton, flatPanoButton, screenOutputButton, /*snapshotButton,*/ flatPanoLabel, screenLabel
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        // 设置所有视图约束
        NSLayoutConstraint.activate([
            // 按钮堆栈靠底
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            // flatImageView：右上角
            flatImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flatImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flatImageView.widthAnchor.constraint(equalToConstant: 140),
            flatImageView.heightAnchor.constraint(equalToConstant: 100),

            // normalImageView：flatImageView 的左侧
            normalImageView.topAnchor.constraint(equalTo: flatImageView.topAnchor),
            normalImageView.trailingAnchor.constraint(equalTo: flatImageView.leadingAnchor, constant: -10),
            normalImageView.widthAnchor.constraint(equalToConstant: 140),
            normalImageView.heightAnchor.constraint(equalToConstant: 100),
        ])
    }

    // MARK: - 配置按钮通用方法
    private func configureButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: - 摄像头连接与断开事件
    @objc private func onCameraConnected() {
        guard let renderView = renderView else { return }

        // 设置视频分辨率
        let name = INSCameraManager.shared().currentCamera?.name
        if name == kInsta360CameraNameNano {
            renderView.enableGyroStabilizer = false
            mediaSession.expectedVideoResolution = INSVideoResolution2560x1280x30
        } else {
            renderView.enableGyroStabilizer = true
            mediaSession.expectedVideoResolution = INSVideoResolution3840x1920x30
        }

        mediaSession.expectedAudioSampleRate = .rate48000Hz
//        snapshotButton.isEnabled = true
    }

    @objc private func onCameraDisconnected() {
//        snapshotButton.isEnabled = false
    }

    // MARK: - 按钮事件处理

    /// 开启或关闭 preview 播放器
    @objc private func togglePreview() {
        guard let renderView = renderView else { return }

        previewButton.isSelected.toggle()
        if previewButton.isSelected {
            previewPlayer = INSCameraPreviewPlayer(renderView: renderView)
            mediaSession.plug(previewPlayer!)
        } else {
            unplug(&previewPlayer)
        }
        updateMediaSession()
    }

    /// 开启或关闭 FlatPano 输出
    @objc private func toggleFlatPano() {
        flatPanoButton.isSelected.toggle()

        if flatPanoButton.isSelected {
            let resolution = mediaSession.expectedVideoResolution
            flatPanoOutput = INSCameraFlatPanoOutput(outputWidth: resolution.width, outputHeight: resolution.height)
            flatPanoOutput?.setDelegate(self, onDispatchQueue: nil)
            mediaSession.plug(flatPanoOutput!)
            flatPanoCounter.reset()
        } else {
            unplug(&flatPanoOutput)
        }
        updateMediaSession()
    }

    /// 开启或关闭屏幕输出
    @objc private func toggleScreenOut() {
        guard let renderView = renderView else { return }

        screenOutputButton.isSelected.toggle()
        if screenOutputButton.isSelected {
            let size = renderView.bounds.size
            screenOutput = INSCameraScreenOutput(
                renderView: renderView,
                outputWidth: Int(size.width),
                outputHeight: Int(size.height),
                outputPixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                outputFrameRate: 30,
                enableAudio: false
            )
            screenOutput?.setDelegate(self, onDispatchQueue: nil)
            mediaSession.plug(screenOutput!)
            screenCounter.reset()
        } else {
            unplug(&screenOutput)
        }
        updateMediaSession()
    }

    /// 截图按钮事件
//    @objc private func takeSnapshot() {
//        if snapshotButton.isSelected { return }
//        snapshotButton.isSelected = true
//    }

    // MARK: - 会话管理
    private func unplug<T>(_ component: inout T?) where T: INSCameraMediaPluggable {
        if let plugin = component {
            mediaSession.unplug(plugin)
        }
        component = nil
    }

    private func updateMediaSession() {
        guard previewPlayer != nil || flatPanoOutput != nil || screenOutput != nil else {
            mediaSession.stopRunning(completion: nil)
            return
        }

        let completion: (Error?) -> Void = { [weak self] error in
            if error != nil {
                self?.resetSession()
            }
        }

        if mediaSession.running {
            mediaSession.commitChanges(completion: completion)
        } else {
            mediaSession.startRunning(completion: completion)
        }
    }

    private func resetSession() {
        previewButton.isSelected = false
        flatPanoButton.isSelected = false
        screenOutputButton.isSelected = false
        mediaSession.unplugAll()
        previewPlayer = nil
        flatPanoOutput = nil
        screenOutput = nil
    }
}

// MARK: - INSCameraAVOutputDelegate 回调处理
extension AVOutputViewController: INSCameraAVOutputDelegate {
    func avOutput(_ avOutput: INSCameraAVOutput, didOutputAudioPacket audioPacket: INSCameraAudioPacket) {
        print("Audio Packet timestamp: \(audioPacket.timestamp)")
    }

    func avOutput(_ avOutput: INSCameraAVOutput, didOutputVideoFrame videoFrame: INSCameraVideoFrame) {
        if avOutput === flatPanoOutput {
            if flatPanoCounter.update(with: videoFrame.timestamp) {
                DispatchQueue.main.async {
                    self.flatPanoLabel.text = self.flatPanoCounter.description
                }
            }
            // 快照显示在 flatImageView
            let image = UIImage(pixelBuffer: videoFrame.pixelBuffer)
            DispatchQueue.main.async {
                self.flatImageView.image = image
            }

        } else if avOutput === screenOutput {
            if screenCounter.update(with: videoFrame.timestamp) {
                DispatchQueue.main.async {
                    self.screenLabel.text = self.screenCounter.description
                }
            }
            // 快照显示在 normalImageView
            let image = UIImage(pixelBuffer: videoFrame.pixelBuffer)
            DispatchQueue.main.async {
                self.normalImageView.image = image
            }
        }
    }
}
