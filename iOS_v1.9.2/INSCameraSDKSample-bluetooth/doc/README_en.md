### Integration

1. embed the INSCameraSDK and INSCoreMedia frameworks to your project target.
![embedframework](./embedframework.png)

2. add an item in the Info.plist. Key is *Supported external accessory protocols*, value is an Array with 3 items `com.insta360.camera`(Nano), `com.insta360.onecontrol`(ONE), `com.insta360.onexcontrol`(ONE X) and `com.insta360.nanoscontrol`(Nano S)
![infoplist](./infoplist.png)

3. Add the following code in your AppDelegate, or somewhere your app is ready to work with Insta360 cameras.

```objc
// Objective-C
#import <INSCameraSDK/INSCameraSDK.h>

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[INSCameraManager sharedManager] setup];
    return YES;
}
```

``` swift
// Swift
import INSCameraSDK`

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    INSCameraManager.shared().setup()
    return true
}
```

4. Call `[[INSCameraManager sharedManager] shutdown]` when your app won't listen on Insta360 cameras any more.

### Monitor Connection of Insta360 Nano, ONE, Nano S Cameras

- register notification for `[NSNotificationCenter defaultCenter]` with the name of `INSCameraDidConnectNotification` or `INSCameraDidDisconnectNotification`

- you can also add KVO on `[INSCameraManager SharedManager].cameraState`, once the cameraState changes to INSCameraStateConnected, your app is able to send commands to the camera.

### Send commands

Familiarity with [`Open Spherical Camera API - Commands`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands) official documentation is a prerequisite for OSC development.

The camera network address is `http://192.168.42.1`.Execute commands via Open Sepherial Camera API[`/osc/commands/execute`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands/execute)

You need to poll yourself to call [`/osc/commands/status`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands/status) to get the execution status of the camera on the current command. The polling cycle can be adjusted according to specific conditions.

Camera support [Open Spherical Camera API level 2](https://developers.google.com/streetview/open-spherical-camera/reference), except preview stream.

#### Connecting with Lightning Interface

When connecting a camera with the Lightning interface, the camera address needs to be changed to `http://localhost:9099`

```Objective-C
#import <Foundation/Foundation.h>

NSDictionary *headers = @{ @"Content-Type": @"application/json",
                           @"X-XSRF-Protected": @"1",
                           @"Accept": @"application/json" };
NSDictionary *parameters = @{ @"name": @"camera.takePicture" };

NSData *postData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];

NSURL *url = [NSURL URLWithString:@"http://localhost:9099/osc/commands/execute"];
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                   timeoutInterval:10.0];
[request setHTTPMethod:@"POST"];
[request setAllHTTPHeaderFields:headers];
[request setHTTPBody:postData];

NSURLSession *session = [NSURLSession sharedSession];
[[session dataTaskWithRequest:[[NSURLRequest alloc] init]
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (error) {
        NSLog(@"%@", error);
    } else {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        NSLog(@"%@", httpResponse);
    }
}] resume];
```

#### Take picture & Record

* You can use [`camera.takePicture`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/takepicture) to take picture.
* You can use [`camera.startCapture`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/startcapture) to start record.
* You can use [`camera.stopCapture `](https://developers.google.com/streetview/open-spherical-camera/reference/camera/stopcapture) to stop record.

#### Options

* You can use [`camera.setOptions`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/setoptions) to set options.
* You can use [`camera.getOptions`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/getoptions) to get options.
* You can know the relevant parameters supported by the camera from [Open Spherical Camera API options](https://developers.google.com/streetview/open-spherical-camera/reference/options).

#### List files

You can use [`camera.listFiles`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/listfiles) to get the files list.

### Status & Informations

#### 1. INSCameraSDK

Not only your app can send commands to the camera, but also the app will receive some notifications from camera when some events happen. For example the batter status changes.
All notifications are listed in NSNotification+INSCamera.h file. Note that the notifications are posted via `INSCameraManager.sharedManager.notificationCenter` instead of `NSNotificationCenter.defaultCenter`.

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    INSCameraManager.shared().notificationCenter.addObserver(self, selector: #selector(handleNotification), name: .INSCameraBatteryStatus, object: nil)
}

func handleNotification(notification: NSNotification) {
    print("receive notification \(notification.name), info: \(String(describing: notification.userInfo))");
    guard let storageStatus = notification.userInfo as? INSCameraBatteryStatus else {
        return
    }

    var msg: String
    switch storageStatus.powerType {
        case .adapter:
            msg = "charging"
        case .battery:
            msg = "left percentage \(Double(batteryLevel) / Double(batteryScale))"
    }
    print("battery status \(msg)")
}
```

#### 2. Open Spherical Camera API

Familiarity with [`Open Spherical Camera API`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc) official documentation is a prerequisite for OSC development.

* You can use [`/osc/info`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/info) to get the basic information about the camera and functionality it supports.
* You can use [`/osc/state`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/state) to get the attributes of the camera.

### Working with audio & video streams

#### Control center - `INSCameraMediaSession`

`INSCameraMediaSession` is the central class to work with audio & video streams for Nano or ONE camera. It has these functions:

1. You can configure the input (the camera) by set the `expectedAudioSampleRate`, `expectedVideoResolution` and `gyroPlayMode`.
2. Control the camera's input streams, turn on by calling `startRunningWithCompletion:`, turn off by call `stopRunningWithCompletion:`.
3. Parse an, decode media data, stitch the video.
4. Distribute outputs to `INSCameraMediaPluggable` such as `INSCameraFlatPanoOutput`.
5. When the session is running, you can change the input configurations, plug or unplug pluggables, make the changes working by call `commitChangesWithCompletion:`.

#### Preview

```swift
import UIKit
import INSCoreMedia
import INSCameraSDK

class PreviewViewController: UIViewController, INSCameraVideoDataDelegate {
    let mediaSession = INSCameraMediaSession()
    var previewPlayer: INSCameraPreviewPlayer!

    deinit {
        mediaSession.unplug(previewPlayer)
        mediaSession.stopRunning { (err) in
            print("stop media session with err: \(String(describing: err))")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        previewPlayer = INSCameraPreviewPlayer(frame: self.bounds, renderType: .sphericalPanoRender)
        self.view.addSubview(previewPlayer.renderView)
        previewPlayer?.renderView.enableGyroStabilizer = true

        mediaSession.plug(previewPlayer)
        mediaSession.expectedVideoResolution = INSVideoResolution2560x1280x30;
        mediaSession.startRunning { (err) in
            print("start running media session with error: \(String(describing: err))")
        }
    }
}
```

### Stitch & HDR

#### Thumbnail

Retrieve thumbnail data from pre-existing files by `INSImageInfoParser` which resolution is 1920 * 960. And then using `INSFlatPanoOffscreenRender` to generate the thumbnail.

You can get thumbnail render and configure output size via `INSFlatPanoOffscreenRender(renderWidth: height:)`

```swift
guard let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "insp") else {
    print("Render: file not found")
    return
}
let url: URL = URL(fileURLWithPath: path)
let parser: INSImageInfoParser = INSImageInfoParser(url: url)
if parser.open() {
    guard let data = parser.extraInfo?.thumbnail else {
        print("Render: no thumbnail")
        return
    }
    guard let thumbnail = UIImage(data: data) else {
        print("Render: generate image failed")
        return
    }
}
```

#### Stitch

Using `INSImageInfoParser` to get the gyroscope data, offset, resolution, etc.

Using `INSFlatPanoOffscreenRender` to get a flat pano image. ( P.s. The parameter, `offset` is nonnull )

```swift 
guard let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "insp") else {
    return
}
guard let origin = UIImage(contentsOfFile: path) else {
    return
}
let url: URL = URL(fileURLWithPath: path)
let parser: INSImageInfoParser = INSImageInfoParser(url: url)
guard parser.open(), let extraInfo: INSExtraInfo = parser.extraInfo, let size = extraInfo.metadata?.dimension else {
    return
}

let render: INSFlatPanoOffscreenRender = INSFlatPanoOffscreenRender(renderWidth: Int32(size.width), height: Int32(size.height))
render.eulerAdjust = extraInfo.metadata?.euler
render.offset = extraInfo.metadata?.offset
if let gyroData = extraInfo.gyroData, let gyroPlayer = INSGyroPBPlayer(pbGyroData: gyroData) {
    let orientation = gyroPlayer.getImageOrientation(with: INSRenderType.flatPanoRender)
    render.gyroStabilityOrientation = orientation
}
else {
    render.gyroStabilityOrientation = GLKQuaternionIdentity
}
render.setRenderImage(origin)
let result: UIImage? = render.renderToImage()
```

### Generate HDR image

Using `INSHDRTask` to generate HDR image. HDR synthesis takes a long time and takes about 5-10 seconds. 

The URLs that is passed into `INSHDROptions` is ordered array, and the array order is [ ev0, -ev, +ev ]. Through the photos taken by ONE X, the default ascending order of the file name is [ ev0, -ev, +ev ].

```swift
let names: [String] = ["IMG_20181029_182547_00_295", "IMG_20181029_182547_00_296", "IMG_20181029_182547_00_297"]
var urls: [URL] = [URL]()
for name in names {
    let path: String = Bundle.main.path(forResource: name, ofType: "insp")!
    let url: URL = URL(fileURLWithPath: path)
    urls.append(url)
}
let options: INSHDROptions = INSHDROptions()
options.urls = urls
options.seamlessType = INSSeamlessType.opticalFlow

let commandManager = INSCameraManager.shared().commandManager
let task: INSHDRTask = INSHDRTask(commandManager: commandManager)
task.process(with: options, completion: { (err, data) in
    if let err = err {
        return
    }
    
    // do anything with the stitched image here, for example, display it
    if let hdrData = data, let hdrImage = UIImage(data: hdrData) {
        self?.displayImage(hdrImage, duration: 5)
    }
})
```

The HDR synthesis algorithm library is divided into two types: ONE X recommends `INSHDRLibInsImgProc`.

```objc
typedef NS_ENUM(NSUInteger, INSHDRLib) {
    /// using `OpenCV` to generate hdr image
    INSHDRLibOpenCV,
    
    /// using `InsImgProLib` to generate hdr image
    INSHDRLibInsImgProc,
};
```

The following two stitching algorithms are encapsulated in HDR synthesis process:

```objc
typedef NS_ENUM(NSUInteger, INSSeamlessType) {
    /// default type
    INSSeamlessTypeTemplate,
    
    /// using Optical flow
    INSSeamlessTypeOpticalFlow,
};
```

### Gyroscope data - `INSMediaGyro`

* You can get the `INSMediaGyro` which contains `ax, ay, az, gx, gy, gz` via `INSImageInfoParser`

```swift
guard let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "insp") else {
    print("Render: file not found")
    return
}
let url: URL = URL(fileURLWithPath: path)
let parser: INSImageInfoParser = INSImageInfoParser(url: url)
if parser.open() {
	let gyro = parser?.gyroData
	print("ax: \(gyro?.ax), ay: \(gyro?.ay), az: \(gyro?.az), gx: \(gyro?.gx), gy: \(gyro?.gy), gz: \(gyro?.gz)")
}
```

* If there is an `INSExtraInfo` instance, `INSMediaGyro` can be directly obtained.

```swift
let gyro = extraInfo.metadata?.gyro
print("ax: \(gyro?.ax), ay: \(gyro?.ay), az: \(gyro?.az), gx: \(gyro?.gx), gy: \(gyro?.gy), gz: \(gyro?.gz)")
```

#### Media gyro ajust

Gyroscopic correction of 2:1 planar images that have been stitched can be done by `INSFlatGyroAdjustOffscreenRender`:

```swift 
guard let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "insp") else {
    return
}
guard let origin = UIImage(contentsOfFile: path) else {
    return
}
let url: URL = URL(fileURLWithPath: path)
let parser: INSImageInfoParser = INSImageInfoParser(url: url)
guard parser.open(), let extraInfo: INSExtraInfo = parser.extraInfo, let size = extraInfo.metadata?.dimension else {
    return
}

let render: INSFlatGyroAdjustOffscreenRender = INSFlatGyroAdjustOffscreenRender(renderWidth: Int32(size.width), height: Int32(size.height))
render.eulerAdjust = extraInfo.metadata?.euler
render.offset = extraInfo.metadata?.offset
if let gyroData = extraInfo.gyroData, let gyroPlayer = INSGyroPBPlayer(pbGyroData: gyroData) {
    let orientation = gyroPlayer.getImageOrientation(with: INSRenderType.flatPanoRender)
    render.gyroStabilityOrientation = orientation
}
else {
    render.gyroStabilityOrientation = GLKQuaternionIdentity
}
render.setRenderImage(origin)
let result: UIImage? = render.renderToImage()
```

### Internal parameters

* Insta360 fisheye distortion:

![INSFisheyeDistortion](./INSFisheyeDistortion.png)

* Opencv fisheye distortion:

![OpenCVFisheyeDistortion](./OpenCVFisheyeDistortion.png)

Using `INSOffsetParser` to get the `INSOffsetParameter` internal parameters

```swift
guard let path: String = Bundle.main.path(forResource: "IMG_20181029_182547_00_295", ofType: "jpg") else {
    print("file not found")
    return
}
let imageParser = INSImageInfoParser(url: URL(fileURLWithPath: path))
let image = UIImage(contentsOfFile: path)
if imageParser.open(), let offset = imageParser.offset {
    let offsetParser = INSOffsetParser(offset: offset, width: Int32(image!.size.width), height: Int32(image!.size.height))
    if let parameters = offsetParser.parameters {
        for param in parameters {
            print("Internal parameters: \(param)")
        }
    }
}
```

### try the sample project and have a look at the header files for more details
