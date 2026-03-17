import UIKit
import INSCameraServiceSDK

// MARK: - 主页面控制器
class RemoteMediaViewController: UITableViewController {
    
    // 数据源
    
    private var imageInfos: [INSCameraBaseFileInfo] = []
    private var videoInfos: [INSCameraBaseFileInfo] = []
    
    private var selectedFiles: [INSCameraBaseFileInfo] = []
    
    let photoSectionIndex = 0
    let videoSectionIndex = 1
    
    // 加载指示器
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            indicator = UIActivityIndicatorView(style: .large)
        } else {
            // 兼容 iOS 12 及以下
            indicator = UIActivityIndicatorView(style: .whiteLarge)
            indicator.color = .gray // 需要手动设置颜色
        }
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    // 初始化UI
    private func setupUI() {
        
        title = "多媒体列表"
        view.backgroundColor = .white
        
        
        // 添加加载指示器
        view.addSubview(loadingIndicator)
        loadingIndicator.center = view.center
        
        // 配置表格视图
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    // 加载数据
    private func loadData() {
        loadingIndicator.startAnimating()
        
        fetchResources(complete: {
            self.tableView.reloadData()
        })
    }
    
    // 显示错误提示
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "加载失败", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "重试", style: .default) { _ in
            self.loadData()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - TableView 数据源
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Image (\(imageInfos.count))" : "Video (Double-tap 1 file or pick 2 files)(\(videoInfos.count))"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? imageInfos.count : videoInfos.count
    }
    
    // MARK: - TableView 数据源（完整替换）
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let text = indexPath.section == 0 ? imageInfos[indexPath.row].uri : videoInfos[indexPath.row].uri
        
        // 版本适配
        if #available(iOS 14.0, *) {
            var config = cell.defaultContentConfiguration()
            config.text = text
            config.image = UIImage(systemName: indexPath.section == 0 ? "photo" : "film")
            cell.contentConfiguration = config
        } else {
            // iOS 13 及以下版本的配置方式
            cell.textLabel?.text = text
            cell.imageView?.image = UIImage(named: indexPath.section == 0 ? "photo_icon" : "video_icon")
        }
        
        // ⬇️ 新增选中标记
        let isSelected = selectedFiles.contains { $0.uri == text } // ⬅️ 修改
        cell.accessoryType = isSelected ? .checkmark : .none        // ⬅️ 修改
        
        return cell
    }
    
    
    // MARK: - 点击事件
    
    // MARK: - 点击事件（完整替换）
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // ⬇️ 移除自动取消选中
        // tableView.deselectRow(at: indexPath, animated: true) // ⬅️ 修改

        let selectedFile: INSCameraBaseFileInfo
        switch indexPath.section {
        case photoSectionIndex:
            
            selectedFile = imageInfos[indexPath.row]
            playImage(imageInfo: selectedFile)
            
        case videoSectionIndex:
            selectedFile = videoInfos[indexPath.row]
            selectedFiles.append(selectedFile)
            
            // 满足两个文件时触发操作
            if selectedFiles.count == 2 {
                playVideo()
                selectedFiles.removeAll()
                tableView.reloadData() // 清除所有选中标记
            }
            
        default:
            return
        }
        
        // 刷新当前单元格显示选中状态
        tableView.reloadRows(at: [indexPath], with: .none)
    }
   
}


extension RemoteMediaViewController {
    func fetchResources(complete:(()->Void?)?) {
        let options = INSGetFileListOptions()
        options.type = .camera
        INSCameraManager.shared().commandManager.fetchPhotoList(with: options) { (err, res) in
            guard let photoList = res?.cameraResources else {
                self.showAlert("fetchPhotoList", String(describing: err))
                return;
            }
            
            self.imageInfos = photoList.sorted(by: { $0.uri > $1.uri })
            self.tableView.reloadSections([self.photoSectionIndex], with: UITableView.RowAnimation.automatic);
            INSCameraManager.shared().commandManager.fetchVideoList(with: options) { (err, res) in
                guard let videoList = res?.cameraResources else {
                    self.showAlert("fetchVideoList", String(describing: err))
                    return;
                }
                
                self.videoInfos = videoList.sorted(by: { $0.uri > $1.uri })
                self.tableView.reloadSections([self.videoSectionIndex], with: UITableView.RowAnimation.automatic);
                complete?()
            }
        }
        
//        guard INSCameraManager.shared().currentCamera?.name != kInsta360CameraNameNano else {
//            return
//        }
    }
    
    
    private func playVideo(){
        guard selectedFiles.count == 2 else { return }
        
        let firstFile = selectedFiles[0]
        let secondFile = selectedFiles[1]
        
        INSCameraManager.shared().commandManager.getFileMnd(withURI: firstFile.uri, type: .metadata, completion: { (err, data) in
            guard let data = data else {
                print("get Video Mnd with error: \(String(describing: err))")
                self.showAlert("get video mnd", String(describing: err))
                return
            }

            let playerController = PlayerViewController()
            playerController.videoURL = INSHTTPURLForResourceURI(firstFile.uri)
            if firstFile.uri != secondFile.uri {
                playerController.videoURL2 = INSHTTPURLForResourceURI(secondFile.uri)
            }
            
                
            self.show(playerController, sender: nil)
        })
    }
    
    private func playImage(imageInfo: INSCameraBaseFileInfo){
        INSCameraManager.shared().commandManager.fetchPhoto(withURI: imageInfo.uri, completion: { (err, photoData) in
            if let err = err {
                print("fetchPhoto with error: \(String(describing: err))")
                self.showAlert("fetchPhoto", String(describing: err))
                return
            }
            let playerController = PlayerViewController()
            playerController.image = UIImage.init(data: photoData!)
            
            let imageUrl = INSHTTPURLForResourceURI(imageInfo.uri)
            playerController.imageURL = imageUrl
            self.show(playerController, sender: nil)
        })
        
    }
}
