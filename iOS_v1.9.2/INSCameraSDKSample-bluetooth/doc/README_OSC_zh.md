### 发送命令

建议在熟悉[`Open Spherical Camera API - Commands`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands/?hl=zh-cn)官方文档后，再进行OSC相关的后续开发。

相机网络地址为`http://192.168.42.1`，调用Open Sepherial Camera API执行命令[`/osc/commands/execute`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands/execute?hl=zh-cn)

针对命令的执行情况，需自行轮询调用[`/osc/commands/status`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands/status)获取相机对当前命令的执行状态。轮询周期可视具体情况调整。

相机支持除预览流外，[Open Spherical Camera API level 2](https://developers.google.com/streetview/open-spherical-camera/reference/?hl=zh-cn)的相关命令

#### 拍照&录像

* 参考Google的Open Spherical Camera API[`camera.takePicture`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/takepicture?hl=zh-cn)进行拍照
* 参考Google的Open Spherical Camera API[`camera.startCapture`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/startcapture?hl=zh-cn)开始录像
* 参考Google的Open Spherical Camera API[`camera.stopCapture `](https://developers.google.com/streetview/open-spherical-camera/reference/camera/stopcapture?hl=zh-cn)停止录像

**HDR模式**

HDR模式拍摄返回参数如下，`[ fileUrl_normal, fileUrl_dark, fielUrl_light ]`为原始双鱼眼图片，HDR图片合成参看后续文档 **HDR合成** 部分

```
{
    "name": "camera.takePicture",
    "state": "done",
    "results": {
        "fileUrl": "http://192.168.42.1:80/DCIM/Camera01/IMG_20181114_163843_00_087.jpg",
        "_fileGroup": {
            "fileUrl_normal": "http://192.168.42.1:80/DCIM/Camera01/IMG_20181114_163843_00_087.jpg",
            "fileUrl_dark": "http://192.168.42.1:80/DCIM/Camera01/IMG_20181114_163843_00_088.jpg",
            "fielUrl_light": "http://192.168.42.1:80/DCIM/Camera01/IMG_20181114_163843_00_089.jpg"
        }
    }
}
```

#### 拍摄参数

* 参考Google的Open Spherical Camera API[`camera.setOptions`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/setoptions?hl=zh-cn)设置相机相关参数
* 参考Google的Open Spherical Camera API[`camera.getOptions`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/getoptions?hl=zh-cn)获取相机相关参数
* 相机相关参数参考[Open Spherical Camera API参数说明](https://developers.google.com/streetview/open-spherical-camera/reference/options?hl=zh-cn)

#### 获取文件

参考Google的Open Spherical Camera API[`camera.listFiles`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/listfiles?hl=zh-cn)获取文件相关信息列表

### 相机状态及其他信息

#### Open Spherical Camera API

建议在熟悉[`Open Spherical Camera API`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/?hl=zh-cn)官方文档后，再进行OSC相关的后续开发。

* 参考Google的Open Spherical Camera API[`/osc/info`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/info?hl=zh-cn)获取相机相关信息
* 参考Google的Open Spherical Camera API[`/osc/state`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/state?hl=zh-cn)获取相机当前状态