### Send commands

Familiarity with [`Open Spherical Camera API - Commands`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands) official documentation is a prerequisite for OSC development.

The camera network address is `http://192.168.42.1`.Execute commands via Open Sepherial Camera API[`/osc/commands/execute`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands/execute)

You need to poll yourself to call [`/osc/commands/status`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/commands/status) to get the execution status of the camera on the current command. The polling cycle can be adjusted according to specific conditions.

Camera support [Open Spherical Camera API level 2](https://developers.google.com/streetview/open-spherical-camera/reference), except preview stream.

#### Take picture & Record

* You can use [`camera.takePicture`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/takepicture) to take picture.
* You can use [`camera.startCapture`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/startcapture) to start record.
* You can use [`camera.stopCapture `](https://developers.google.com/streetview/open-spherical-camera/reference/camera/stopcapture) to stop record.

**HDR mode**

HDR mode shooting response are as follows, you can use the original spherical images `[ fileUrl_normal, fileUrl_dark, fielUrl_light ]` to generate HDR image, and get more information from following documents **Generate HDR image** section.

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

#### Options

* You can use [`camera.setOptions`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/setoptions) to set options.
* You can use [`camera.getOptions`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/getoptions) to get options.
* You can know the relevant parameters supported by the camera from [Open Spherical Camera API options](https://developers.google.com/streetview/open-spherical-camera/reference/options).

#### List files

You can use [`camera.listFiles`](https://developers.google.com/streetview/open-spherical-camera/reference/camera/listfiles) to get the files list.

### Status & Informations

#### Open Spherical Camera API

Familiarity with [`Open Spherical Camera API`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc) official documentation is a prerequisite for OSC development.

* You can use [`/osc/info`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/info) to get the basic information about the camera and functionality it supports.
* You can use [`/osc/state`](https://developers.google.cn/streetview/open-spherical-camera/guides/osc/state) to get the attributes of the camera.
