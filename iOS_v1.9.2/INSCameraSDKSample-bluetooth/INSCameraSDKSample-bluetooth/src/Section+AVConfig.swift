//
//  Section+AVConfig.swift
//  INSCameraSDK
//
//  Created by zeng bin on 5/24/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import Foundation
import INSCameraSDK
import Eureka


extension INSVideoResolution: CustomStringConvertible {
    public var description: String {
        return "\(width)x\(height) \(fps)"
    }
    
    init(description: String) {
        let subStrings = description.components(separatedBy: " ")
        let fps = Int(subStrings[1])!
        let sizeStrings = subStrings[0].components(separatedBy: "x")
        let width = Int(sizeStrings[0])!
        let height = Int(sizeStrings[1])!
        self.init(width: width, height: height, fps: fps, type: 0)
    }
}

extension INSAudioFormat: CustomStringConvertible {
    public var description: String {
        switch self {
        case .aacRaw:
            return "Raw AAC"
        case .aacAdts:
            return "AAC ADTS"
        default:
            return ""
        }
    }
    
    static func audioFormatBy(description: String) -> INSAudioFormat {
        if description == INSAudioFormat.aacRaw.description {
            return .aacRaw
        } else if description == INSAudioFormat.aacAdts.description {
            return .aacAdts
        }
        return .aacRaw;
    }
}

extension INSGyroPlayMode: CustomStringConvertible {
    public var description: String {
        if self == .default {
            return "Default"
        }
        if self == .none {
            return "None"
        }
        if self == .normal {
            return "Normal"
        }
        if self == .removeYawRotations {
            return "Remove Yaw Rotations"
        }
        if self == .focusedToCameraBaseRotation {
            return "Focus to camera"
        }
        return "Unknown"
    }
    
    static func gyroPlayModeBy(description: String) -> INSGyroPlayMode {
        if description == INSGyroPlayMode.default.description {
            return .default
        }
        if description == INSGyroPlayMode.none.description {
            return .none
        }
        if description == INSGyroPlayMode.normal.description {
            return .normal
        }
        if description == INSGyroPlayMode.removeYawRotations.description {
            return .removeYawRotations
        }
        if description == INSGyroPlayMode.focusedToCameraBaseRotation.description {
            return .focusedToCameraBaseRotation
        }
        return .default;
    }
}

struct VideoResolutions {
    
    static var Nano: [INSVideoResolution] {
        let resolutions: [INSVideoResolution] = [
            INSVideoResolution(width: 0, height: 0, fps: 0, type: 0),
            INSVideoResolution2560x1280x30,
            INSVideoResolution2160x1080x30,
            INSVideoResolution1920x960x30,
        ]
        return resolutions
    }
    
    static var ONE: [INSVideoResolution] {
        let resolutions: [INSVideoResolution] = [
            INSVideoResolution(width: 0, height: 0, fps: 0, type: 0),
            INSVideoResolution3840x1920x30,
            INSVideoResolution2560x1280x30,
            INSVideoResolution1920x960x30,
            INSVideoResolution2560x1280x60,
            INSVideoResolution2048x512x120,
            INSVideoResolution3328x832x60,
        ]
        return resolutions
    }
    
    static var NanoS: [INSVideoResolution] {
        let resolutions: [INSVideoResolution] = [
            INSVideoResolution(width: 0, height: 0, fps: 0, type: 0),
            INSVideoResolution3840x1920x30,
            INSVideoResolution3072x1536x30,
            INSVideoResolution2560x1280x30,
            INSVideoResolution2240x1120x30,
            INSVideoResolution2240x1120x24,
            INSVideoResolution1920x960x30,
            INSVideoResolution1440x720x30,
        ]
        return resolutions
    }
    
    static var ONEX: [INSVideoResolution] {
        let resolutions: [INSVideoResolution] = [
            INSVideoResolution(width: 0, height: 0, fps: 0, type: 0),
            INSVideoResolution2880x2880x30,
            INSVideoResolution2880x2880x25,
            INSVideoResolution2880x2880x24,
            INSVideoResolution3840x1920x60,
            INSVideoResolution3840x1920x50,
            INSVideoResolution3840x1920x30,
            INSVideoResolution3072x1536x30,
            INSVideoResolution3008x1504x100,
            INSVideoResolution3040x1520x30,
            INSVideoResolution2560x1280x30,
            INSVideoResolution2176x1088x30,
            INSVideoResolution1440x720x30,
        ]
        return resolutions
    }
    
    static var EVO: [INSVideoResolution] {
        return VideoResolutions.ONEX
    }
    
    static var Go: [INSVideoResolution] {
        let resolutions: [INSVideoResolution] = [
            INSVideoResolution(width: 0, height: 0, fps: 0, type: 0),
            INSVideoResolution2720x2720x25,
        ]
        return resolutions
    }
    
    static var ONER: [INSVideoResolution] {
        let single: [INSVideoResolution] = [
            INSVideoResolution(width: 0, height: 0, fps: 0, type: 0),
            INSVideoResolution3840x2160x60,
            INSVideoResolution3840x2160x30,
            INSVideoResolution2720x1530x100,
            INSVideoResolution1920x1080x240,
            INSVideoResolution5472x3078x30,
            INSVideoResolution5312x2988x30,
            INSVideoResolution2720x1530x60,
            INSVideoResolution2720x1530x30,
            INSVideoResolution1920x1080x60,
            INSVideoResolution2720x2040x30,
            INSVideoResolution1920x1440x30,
            INSVideoResolution1280x720x30,
            INSVideoResolution1280x960x30,
            INSVideoResolution1152x768x30,
            
            INSVideoResolution5312x2988x25,
            INSVideoResolution5312x2988x24,
            INSVideoResolution3840x2160x25,
            INSVideoResolution3840x2160x24,
            INSVideoResolution2720x1530x25,
            INSVideoResolution2720x1530x24,
            INSVideoResolution1920x1080x25,
            INSVideoResolution1920x1080x24,
            INSVideoResolution4000x3000x25,
            INSVideoResolution4000x3000x24,
            INSVideoResolution2720x2040x25,
            INSVideoResolution2720x2040x24,
            INSVideoResolution1920x1440x25,
            INSVideoResolution1920x1440x24,
        ]
        let multiple: [INSVideoResolution] = VideoResolutions.ONEX
        
        return single + multiple
    }
    
    static var secondStreamReses: [INSVideoResolution] = [
        INSVideoResolution(width: 0, height: 0, fps: 0, type: 0),
        INSVideoResolution960x480x30,
        INSVideoResolution720x360x30,
        INSVideoResolution480x240x30,
        INSVideoResolution640x320x30,
        INSVideoResolution640x320x15,
        INSVideoResolution640x320x8,
        INSVideoResolution1024x512x30,
        INSVideoResolution1024x512x15,
        INSVideoResolution1024x512x8,
    ]
}

struct PhotoSize {
    
    static var `default`: [INSPhotoSize] {
        let sizes:[INSPhotoSize] = [
            INSMakePhotoSize(0, 0),
            INSPhotoSize6912x3456,
            INSPhotoSize6272x3136,
            INSPhotoSize6080x3040,
        ]
        return sizes
    }
    
    static var Go: [INSPhotoSize] {
        let sizes:[INSPhotoSize] = [
            INSMakePhotoSize(0, 0),
            INSPhotoSize3040x3040,
        ]
        return sizes
    }
}

let previewStreams:[Int] = [0,1]
let previewRotations:[Int] = [0,1]
let audioSampleRates:[Int] = [44100, 48000]
let audioFormats:[INSAudioFormat] = [.aacRaw, .aacAdts]
let gyroModes:[INSGyroPlayMode] = [.default, .none, .normal,
                                   .removeYawRotations, .focusedToCameraBaseRotation]

let audioFormatsString:[String] = audioFormats.map { $0.description }
let gyroModesString:[String] = gyroModes.map { $0.description }

let defaultVideoResolution = INSVideoResolution1024x512x15//INSVideoResolution3840x1920x30
let defaultVideoResolutionSecondary = INSVideoResolution960x480x30
let defaultPreviewNum = previewStreams[1]
let defaultPreviewRotation = previewRotations[0]
let defaultAudioSampleRate = audioSampleRates[1]
let defaultAudioFormat = audioFormats[1]
let defaultGyroPlaymode = gyroModes[0]

protocol AVConfigProtocol {
    
    func setupConfigSection() -> Section
    
    var avConfigSection: Section? { get set }
    var inputVideoResolution: INSVideoResolution { get }
    var inputVideoResolution2: INSVideoResolution { get }
    var previewStreamNum: Int { get }
    var previewStreamRotation: Int{ get }
    var outputVideoResolution: INSVideoResolution { get }
    var gyroPlayMode: INSGyroPlayMode { get }
    var audioSampleRate: INSAudioSampleRate { get }
    var audioFormat: INSAudioFormat { get }
    var useLocalDeviceAudio: Bool { get }
}

extension AVConfigProtocol {
    func setupConfigSection() -> Section {
        let section = Section("AV Config")
        section <<< ActionSheetRow<String>("Input Video Resolution") {
            $0.title = $0.tag
            $0.value = defaultVideoResolution.description
            
            let cameraType: String? = INSCameraManager.shared().currentCamera?.cameraType
            $0.options = self.videoResolutions(cameraType: cameraType).map({ (resolution) -> String in
                return resolution.description
            })
        }
        section <<< ActionSheetRow<String>("Input Video Resolution2") {
            $0.title = $0.tag
            $0.value = defaultVideoResolutionSecondary.description
            
            let cameraType: String? = INSCameraManager.shared().currentCamera?.cameraType
            $0.options = self.secondaryStreamResolutions(cameraType: cameraType).map({ (resolution) -> String in
                return resolution.description
            })
        }
        <<< ActionSheetRow<Int>("PreviewNum") {
            $0.title = "\($0.tag!): (0-Main 1-Secondary)"
            $0.value = defaultPreviewNum
            $0.options = previewStreams
        }
        <<< ActionSheetRow<Int>("PreviewRotation") {
            $0.title = "\($0.tag!): (0-None 1-Horizon180)"
            $0.value = defaultPreviewRotation
            $0.options = previewRotations
        }
        <<< ActionSheetRow<String>("Output Video Resolution") {
            $0.title = $0.tag
            $0.value = defaultVideoResolution.description
            
            let cameraType: String? = INSCameraManager.shared().currentCamera?.cameraType
            $0.options = self.videoResolutions(cameraType: cameraType).map({ (resolution) -> String in
                return resolution.description
            })
        }
        <<< ActionSheetRow<String>("Gyro play mode") {
            $0.title = $0.tag
            $0.value = defaultGyroPlaymode.description
            $0.options = gyroModesString
        }
        <<< ActionSheetRow<Int>("Audio Sample Rate") {
            $0.title = $0.tag
            $0.value = defaultAudioSampleRate
            $0.options = audioSampleRates
        }
        <<< ActionSheetRow<String>("Audio Format") {
            $0.title = $0.tag
            $0.value = defaultAudioFormat.description
            $0.options = audioFormatsString
        }
//        <<< SwitchRow("Use iOS Device's Audio") {
//            $0.title = $0.tag
//            $0.value = false
//        }
        return section;
    }
    
    var inputVideoResolution: INSVideoResolution {
        if let row: ActionSheetRow<String> = avConfigSection?.rowBy(tag: "Input Video Resolution") {
            return INSVideoResolution(description: row.value!)
        }
        return defaultVideoResolution
    }
    
    var inputVideoResolution2: INSVideoResolution {
        if let row: ActionSheetRow<String> = avConfigSection?.rowBy(tag: "Input Video Resolution2") {
            return INSVideoResolution(description: row.value!)
        }
        return defaultVideoResolutionSecondary
    }
    
    var previewStreamNum: Int {
        if let row: ActionSheetRow<Int> = avConfigSection?.rowBy(tag: "PreviewNum") {
            return previewStreams[row.value!]
        }
        return defaultPreviewNum
    }
    
    var previewStreamRotation: Int {
        if let row: ActionSheetRow<Int> = avConfigSection?.rowBy(tag: "PreviewRotation") {
            return previewRotations[row.value!]
        }
        return defaultPreviewRotation
    }
    
    var outputVideoResolution: INSVideoResolution {
        if let row: ActionSheetRow<String> = avConfigSection?.rowBy(tag: "Output Video Resolution") {
            return INSVideoResolution(description: row.value!)
        }
        return defaultVideoResolution
    }
    
    var audioSampleRate: INSAudioSampleRate {
        if let row: ActionSheetRow<Int> = avConfigSection?.rowBy(tag: "Audio Sample Rate") {
            return INSAudioSampleRateWithValue(row.value!)
        }
        return INSAudioSampleRateWithValue(defaultAudioSampleRate)
    }
    
    var audioFormat: INSAudioFormat {
        if let row: ActionSheetRow<String> = avConfigSection?.rowBy(tag: "Audio Format") {
            return INSAudioFormat.audioFormatBy(description: row.value!)
        }
        return defaultAudioFormat
    }
    
    var gyroPlayMode: INSGyroPlayMode {
        if let row: ActionSheetRow<String> = avConfigSection?.rowBy(tag: "Gyro play mode") {
            return INSGyroPlayMode.gyroPlayModeBy(description: row.value!)
        }
        return defaultGyroPlaymode
    }
    
    var useLocalDeviceAudio: Bool {
        if let row: SwitchRow = avConfigSection?.rowBy(tag: "Use iOS Device's Audio") {
            return row.value ?? false
        }
        return false
    }
}

extension AVConfigProtocol {
    
    func secondaryStreamResolutions(cameraType: String?) -> [INSVideoResolution] {
        return VideoResolutions.secondStreamReses
    }
    
    func videoResolutions(cameraType: String?) -> [INSVideoResolution] {
        switch cameraType {
        case kInsta360CameraNameNano:
            return VideoResolutions.Nano
            
        case kInsta360CameraNameOne:
            return VideoResolutions.ONE
            
        case kInsta360CameraNameNanoS:
            return VideoResolutions.NanoS
            
//        case kInsta360CameraNameOneX:
//            return VideoResolutions.ONEX + VideoResolutions.secondStreamReses
            
        case kInsta360CameraNameEVO:
            return VideoResolutions.EVO
            
        case kInsta360CameraNameGo:
            return VideoResolutions.Go
            
        case kInsta360CameraNameOneR:
            return VideoResolutions.ONER
            
        default:
            break
        }
        return VideoResolutions.ONEX + VideoResolutions.secondStreamReses
    }
}
