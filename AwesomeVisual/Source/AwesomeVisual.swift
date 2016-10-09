//
// AwesomeVisual.swift
//
// Copyright © 2016 2sui
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the “Software”), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
// PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
// FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//

import UIKit
import AVFoundation
import GPUImage


// MARK: - Log and Debug.

enum AwesomeVisualMessageType: String {
    case Error = "Error"
    case Warn = "Warn"
    case Info = "Info"
    case Debug = "Debug"
    
    static let escape: String = {
#if ENABLE_MESSAGE_COLOR
        return "\u{001b}["
#else
        return ""
#endif
    }()
    
    static let reset: String = {
#if ENABLE_MESSAGE_COLOR
        return escape + ";"
#else
        return ""
#endif
    }()
    
    static let redColor: String = {
#if ENABLE_MESSAGE_COLOR
        return "fg255,0,0;"
#else
        return ""
#endif
    }()
    
    static let yellowColor: String = {
#if ENABLE_MESSAGE_COLOR
        return "fg255,255,0;"
#else
        return ""
#endif
    }()
    
    static let greenColor: String = {
#if ENABLE_MESSAGE_COLOR
        return "fg0,255,0;"
#else
        return ""
#endif
    }()
    
    static let whiteColor: String = {
#if ENABLE_MESSAGE_COLOR
        return "fg255,255,255;"
#else
        return ""
#endif
    }()
    
    func ColorValue() -> String {
        switch self {
            case .Error:
            return AwesomeVisualMessageType.redColor
            case .Warn:
            return AwesomeVisualMessageType.yellowColor
            case .Info:
            return AwesomeVisualMessageType.whiteColor
            case .Debug:
            return AwesomeVisualMessageType.greenColor
        }
    }
    
    func ColorMessage(message: String) -> String {
        return "\(AwesomeVisualMessageType.escape)\(ColorValue())[\(self.rawValue)] \(message)\(AwesomeVisualMessageType.reset)"
    }
}

func AwesomeVisualMessage(type: AwesomeVisualMessageType, info: String) {
    switch type {
    case .Debug:
#if !ENABLE_MESSAGE_DEBUG
        return
#endif
        break
    case .Info:
#if !ENABLE_MESSAGE_INFO
        return
#endif
        break
    case .Warn:
#if !ENABLE_MESSAGE_WARN
        return
#endif
        break
    case .Error:
#if DISABLE_MESSAGE_ERROR
        return
#endif
        break
    }
    
    NSLog("\(type.ColorMessage(info))")
}


// MARK: - Visual State

public enum VisualStat {
    case Failed
    case NotAuthorized
    case Authorized
    case Error
    case Success
}


// MARK: - AwesomeVisual Type

public enum AwesomeVisualType {
    case Normal
    case GPUImage
}


// MARK: - Basic class of AwesomeVisual

public class AwesomeVisualObject: NSObject {
    private static var awesomeVisualVideoQueueSpecific = "com.awesomevisual.video"
    private static var awesomeVisualAudioQueueSpecific = "com.awesomevisual.audio"
    public static var videoDevices: [AVCaptureDevice] = {
        let deviceArray = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        var devices = [AVCaptureDevice]()
        
        for device in deviceArray {
            if let dev = device as? AVCaptureDevice {
                devices.append(dev)
            }
        }
        
        return devices
    }()
    public static var audioDevices: [AVCaptureDevice] = {
        let deviceArray = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio)
        var devices = [AVCaptureDevice]()
        
        for device in deviceArray {
            if let dev = device as? AVCaptureDevice {
                devices.append(dev)
            }
        }
        
        return devices
    }()
    public static var awesomeVisualVideoQueue: dispatch_queue_t = {
        let queue = dispatch_queue_create(awesomeVisualVideoQueueSpecific, DISPATCH_QUEUE_SERIAL)
        dispatch_queue_set_specific(queue, &awesomeVisualVideoQueueSpecific, AwesomeVisualObject.getMutablePointer(AwesomeVisualObject.self), nil)
        return queue
    }()
    public static var awesomeVisualAudioQueue: dispatch_queue_t = {
        let queue = dispatch_queue_create(awesomeVisualAudioQueueSpecific, DISPATCH_QUEUE_SERIAL)
        dispatch_queue_set_specific(queue, &awesomeVisualAudioQueueSpecific, AwesomeVisualObject.getMutablePointer(AwesomeVisualObject.self), nil)
        return queue
    }()
    
    class func getMutablePointer(object: AnyObject) -> UnsafeMutablePointer<Void> {
        return UnsafeMutablePointer<Void>(bitPattern: Int(ObjectIdentifier(object).uintValue))
    }
    
    class func isQueue(key: String) -> Bool {
        return dispatch_get_specific(&awesomeVisualVideoQueueSpecific) != nil
    }
    
    class func dispatchInVideoQueue(closure: () -> Void) {
        if isQueue(awesomeVisualVideoQueueSpecific) {
            closure()
            
        } else {
            dispatch_async(awesomeVisualVideoQueue, closure)
        }
    }
    
    class func dispatchInAudioQueue(closure: () -> Void) {
        if isQueue(awesomeVisualAudioQueueSpecific) {
            closure()
            
        } else {
            dispatch_async(awesomeVisualAudioQueue, closure)
        }
    }
    
    var mediaStat: VisualStat = .Failed
        
    public var visualStat: VisualStat {
        return mediaStat
    }
    
}


// MARK: - AwesomeVisual Delegate: DO NOT Lock the device in delegate, also they all run in AwesomeVisual queue.

@objc
public protocol AwesomeVisualDelegate: NSObjectProtocol {
    
    // session
    optional func configSession(awesomeVisual: AwesomeVisual, session: AVCaptureSession)
    
    // devices
    optional func configInputVideoDeviceBeforeRunning(awesomeVisual: AwesomeVisual, device: AVCaptureDevice, withConnection connection: AVCaptureConnection?)
    optional func configInputAudioDeviceBeforeRunning(awesomeVisual: AwesomeVisual, device: AVCaptureDevice, withConnection connection: AVCaptureConnection?)
    
    // output
    optional func settingsOutputVideo(awesomeVisual: AwesomeVisual) -> [NSObject : AnyObject]
    
    // asset writer
    func shouldEneableAssetWriter(awesomeVisual: AwesomeVisual) -> Bool
    
    // video maker
    func shouldEnableMergeAssetWriter(awesomeVisual: AwesomeVisual) -> Bool
}


// MARK: - AwesomeVisual Class

public class AwesomeVisual: AwesomeVisualObject, AwesomeVisualDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    var type: AwesomeVisualType
    
    // AVFoundation
    private var session: AVCaptureSession?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var sessionRunningContext: UnsafeMutablePointer<Void>!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var containerView: UIView?
    private var observerIsAdded = false
    
    // GPUImage
    weak var gpuImageOutputEndPoint: GPUImageOutput?
    var gpuImageVideoCamera: GPUImageCameraForAwesomeVisual?
    var gpuImageDataOutput: GPUImageRawOutputForAwesomeVisual?
    var gpuImageView: GPUImageView?
    
    // Recorder
    private var recorder: AwesomeVisualRecorder?
    
    // av capture device
    public weak var _delegate: AwesomeVisualDelegate?
    public weak var videoInputDevice: AVCaptureDevice?
    public weak var audioInputDevice: AVCaptureDevice?
    public weak var targetSession: AVCaptureSession?
    public weak var targetVideoInput: AVCaptureDeviceInput?
    public weak var targetAudioInput: AVCaptureDeviceInput?
    public weak var targetVideoOutput: AVCaptureVideoDataOutput?
    public weak var targetAudioOutput: AVCaptureAudioDataOutput?
    
    public init(type: AwesomeVisualType = .GPUImage) {
        self.type = type
        super.init()
        
        switch self.type {
        case .Normal:
            session = AVCaptureSession()
            sessionRunningContext = UnsafeMutablePointer<Void>.alloc(1)
            targetSession = session
            
        case .GPUImage:
            AwesomeVisualMessage(.Info, info: "Using GPUImage")
        }
        
        videoInputDevice = getVideoDeviceWithPosition(.Back)
        audioInputDevice = getAudioDeviceForFirst()
        _delegate = self
    }
    
    deinit {
        recorder = nil
        
        switch type {
        case .Normal:
            unprepareSession()
            sessionRunningContext.dealloc(1)
            
        case .GPUImage:
            unprepareGPUImage()
        }
        
        AwesomeVisualMessage(.Debug, info: "AwesomeVisual deinit")
    }
    
    
    // public
    
    // video gravity
    public var videoGravity = AVLayerVideoGravityResizeAspectFill
    
    // video orientation
    public var videoOrientation = AVCaptureVideoOrientation.Portrait
}


// MARK: - Public Method.

// MARK: - Framework Interface.

extension AwesomeVisual {

    public weak var delegate: AwesomeVisualDelegate? {
        set {
            if nil != newValue {
                _delegate = newValue
            }
        }
        
        get {
            return nil
        }
    }
    
    public var segmentRecoder: AwesomeVisualRecorder {
        if nil == recorder {
            recorder = AwesomeVisualRecorder(visual: self)
        }
        
        return recorder!
    }
    
    // is running ?
    public var isSessionRunning: Bool {
        switch type {
        case .Normal:
            return session!.running
            
        case .GPUImage:
            return gpuImageVideoCamera?.isRunning ?? false
        }
    }
    
    // camera position
    public var cameraPosition: AVCaptureDevicePosition {
        set {
            let strongSelf = self
            AwesomeVisual.dispatchInVideoQueue {
                guard strongSelf.isSessionRunning else {
                    return
                }
                
                switch strongSelf.type {
                case .Normal:
                    if newValue == strongSelf.videoInputDevice!.position {
                        return
                    }
                    
                    strongSelf.videoInputDevice = strongSelf.getVideoDeviceWithPosition(newValue)
                    strongSelf.session!.beginConfiguration()
                    strongSelf.initVideoInput(strongSelf.videoInputDevice!)
                    strongSelf.session!.commitConfiguration()
                    strongSelf.targetVideoInput = strongSelf.videoInput
                    
                case .GPUImage:
                    strongSelf.gpuImageVideoCamera!.rotateCamera()
                    strongSelf.targetVideoInput = strongSelf.gpuImageVideoCamera!.sessionVideoInput
                }
            }
        }
        
        get {
            return isSessionRunning ? targetVideoInput!.device.position : .Back
        }
    }
    
    public var autoFocus: Bool {
        set {
            let strongSelf = self
            AwesomeVisual.dispatchInVideoQueue {
                guard strongSelf.isSessionRunning else {
                    return
                }
                
                if !newValue {
                    strongSelf.focusWithMode(AVCaptureFocusMode.ContinuousAutoFocus, forDevice: strongSelf.targetVideoInput!.device, exposeWithMode: AVCaptureExposureMode.ContinuousAutoExposure, atDevicePoint: CGPointMake(0.5, 0.5), monitorSubjectAreaChange: true)
                    
                } else {
                    strongSelf.focusWithMode(AVCaptureFocusMode.AutoFocus, forDevice: strongSelf.targetVideoInput!.device, exposeWithMode: AVCaptureExposureMode.AutoExpose, atDevicePoint: CGPointMake(0.5, 0.5), monitorSubjectAreaChange: false)
                }
            }
        }
        
        get {
            return isSessionRunning ? targetVideoInput!.device.subjectAreaChangeMonitoringEnabled : false
        }
    }
    
    // flash mode
    public var flashMode: AVCaptureFlashMode {
        set {
            let strongSelf = self
            AwesomeVisual.dispatchInVideoQueue {
                guard strongSelf.isSessionRunning else {
                    return
                }
                
                strongSelf.setFlashMode(newValue, forDevice: strongSelf.targetVideoInput!.device)
            }
        }
        
        get {
            return isSessionRunning ? targetVideoInput!.device.flashMode : AVCaptureFlashMode.Off
        }
    }
    
    // tap to focus
    public func focusAndExposeTap(gestureRecognizer: UIGestureRecognizer) {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            guard strongSelf.isSessionRunning else {
                return
            }
            
            var devicePoint = CGPointZero
            
            switch strongSelf.type {
            case .Normal:
                if strongSelf.containerView == nil || strongSelf.previewLayer == nil || strongSelf.containerView != gestureRecognizer.view {
                    return
                }
                
                devicePoint = strongSelf.previewLayer!.captureDevicePointOfInterestForPoint(gestureRecognizer.locationInView(gestureRecognizer.view))
                
            case .GPUImage:
                if strongSelf.gpuImageView == nil || gestureRecognizer.view != strongSelf.gpuImageView {
                    return
                }
                
                let viewBounds = gestureRecognizer.view!.bounds
                let viewPoint = gestureRecognizer.locationInView(gestureRecognizer.view)
                devicePoint = CGPointMake(viewPoint.y / viewBounds.height, (viewBounds.width - viewPoint.x) / viewBounds.width)
            }
            
            /**
             This property represents a CGPoint where {0,0} corresponds to the top left of the picture area, and {1,1} corresponds to the bottom right in landscape mode with the home button on the right—this applies even if the device is in portrait mode.
             */
            strongSelf.focusWithMode(AVCaptureFocusMode.AutoFocus, forDevice: strongSelf.targetVideoInput!.device, exposeWithMode: AVCaptureExposureMode.AutoExpose, atDevicePoint: devicePoint, monitorSubjectAreaChange: true)
        }
    }
    
    
    public func prepareVisual(complete: ((AwesomeVisual) -> Void)?) {
        requestForVideoAuth {
            statu in
            if .Authorized == statu {
                switch self.type {
                case .Normal:
                    self.prepareSession(complete)
                    
                case .GPUImage:
                    self.prepareGPUImage(complete)
                }
                
            } else {
                complete?(self)
            }
        }
    }
    
    public func preparePreviewLayer(frame: CGRect) -> UIView? {
        if mediaStat == .Success {
            switch type {
            case .Normal:
                initOriginalPreview(frame)
                return containerView!
                
            case .GPUImage:
                initGPUImageView(frame)
                return gpuImageView!
            }
        }
        
        return nil
    }
    
    public func removePreviewLayer() {
        if mediaStat == .Success {
            switch type {
            case .Normal:
                deinitOriginalPreview()
                
            case .GPUImage:
                deinitGPUImageView()
            }
        }
    }
    
    public func startCapture(didStart: ((AwesomeVisual) -> Void)?) {
        if mediaStat == .Success {
            if !isSessionRunning {
                switch type {
                case .Normal:
                    let strongSelf = self
                    AwesomeVisual.dispatchInVideoQueue {
                        strongSelf.processSessionStart(didStart)
                        AwesomeVisualMessage(.Info, info: "Media session start running.")
                    }
                    
                case .GPUImage:
                    gpuImageVideoCamera!.startCameraCapture()
                    AwesomeVisualMessage(.Info, info: "Media session start running.")
                    didStart?(self)
                }
                
            }
            
        } else {
            AwesomeVisualMessage(.Warn, info: "Media session not running.")
        }
    }
    
    public func stopCapture(didStop: ((AwesomeVisual) -> Void)?) {
        if mediaStat == .Success {
            if isSessionRunning {
                
                switch type {
                case .Normal:
                    let strongSelf = self
                    AwesomeVisual.dispatchInVideoQueue {
                        strongSelf.processSessionStop(didStop)
                        AwesomeVisualMessage(.Info, info: "Media session stop running.")
                    }
                    
                case .GPUImage:
                    recorder?.preferRecordStop(true, complete: nil)
                    runSynchronouslyOnVideoProcessingQueue {
                        self.gpuImageVideoCamera!.stopCameraCapture()
                    }
                    AwesomeVisualMessage(.Info, info: "Media session stop running.")
                    didStop?(self)
                }
            }
        }
    }
    
    
    public func startRecord() {
        guard _delegate?.shouldEneableAssetWriter(self) ?? false else {
            return
        }
        
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            strongSelf.segmentRecoder.preferRecordStart()
        }
    }
    
    public func pauseRecord() {
        guard _delegate?.shouldEneableAssetWriter(self) ?? false && nil != recorder else {
            return
        }
        
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            strongSelf.recorder!.preferRecordPause()
        }
    }
    
    public func resumeRecord() {
        guard _delegate?.shouldEneableAssetWriter(self) ?? false && nil != recorder else {
            return
        }
        
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            strongSelf.recorder!.preferRecordResume()
        }
    }
    
    public func stopRecord() {
        guard _delegate?.shouldEneableAssetWriter(self) ?? false && nil != recorder else {
            return
        }
        
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            strongSelf.recorder!.preferRecordStop(false, complete: nil)
        }
    }
    
    public func makeupVideo(complete: ((output: String?) -> Void)?) {
        guard nil != recorder && _delegate?.shouldEnableMergeAssetWriter(self) ?? false else {
            complete?(output: nil)
            return
        }
        
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            strongSelf.recorder!.mergeSegments(complete)
        }
        
    }
}


// MARK: - Private Method.

extension AwesomeVisual {
    
    private func getVideoDeviceWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        
        for device in AwesomeVisual.videoDevices {
            if device.position == position {
                return device
            }
        }
        
        AwesomeVisualMessage(.Warn, info: "No targeted video device.")
        return nil
    }
    
    private func getAudioDeviceForFirst() -> AVCaptureDevice? {
        if AwesomeVisual.audioDevices.count > 0 {
            return AwesomeVisual.audioDevices[0]
        }
        
        AwesomeVisualMessage(.Warn, info: "No targeted audio device.")
        return nil
    }
    
    private func requestForVideoAuth(complete: ((VisualStat) ->Void)) {
        switch AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) {
        case AVAuthorizationStatus.Authorized:
            mediaStat = .Authorized
            complete(mediaStat)
            
        case AVAuthorizationStatus.NotDetermined:
            dispatch_suspend(AwesomeVisual.awesomeVisualVideoQueue)
            dispatch_suspend(AwesomeVisual.awesomeVisualAudioQueue)
            let strongSelf = self
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) {
                granted in
                strongSelf.mediaStat = granted ? .Authorized : .NotAuthorized
                dispatch_resume(AwesomeVisual.awesomeVisualVideoQueue)
                dispatch_resume(AwesomeVisual.awesomeVisualAudioQueue)
                complete(strongSelf.mediaStat)
            }
            
        default:
            mediaStat = .NotAuthorized
            complete(mediaStat)
        }
    }
    
    private func initVideoInput(input: AVCaptureDevice) -> Bool {
        if nil == videoInput {
            do {
                videoInput = try AVCaptureDeviceInput(device: input)
                
                if session!.canAddInput(videoInput!) {
                    session!.addInput(videoInput!)
                    targetVideoInput = videoInput
                    // default auto focus
                    focusWithMode(AVCaptureFocusMode.ContinuousAutoFocus, forDevice: targetVideoInput!.device, exposeWithMode: AVCaptureExposureMode.ContinuousAutoExposure, atDevicePoint: CGPointMake(0.5, 0.5), monitorSubjectAreaChange: true)

                    AwesomeVisualMessage(.Info, info: "Video input added.")
                    return true
                }
                
            } catch {
                AwesomeVisualMessage(.Warn, info: "Video input create fail.")
            }
            
            videoInput = nil
            AwesomeVisualMessage(.Warn, info: "Video input added fail.")
            return false
        }
        
        if input == videoInput!.device {
            return true
            
        } else {
            deinitVideoInput()
        }
        
        return initVideoInput(input)
    }
    
    private func deinitVideoInput() {
        if nil != videoInput {
            session!.removeInput(videoInput!)
            videoInput = nil
            AwesomeVisualMessage(.Info, info: "Video input removed.")
        }
    }
    
    private func initAudioInput(input: AVCaptureDevice) -> Bool {
        if nil == audioInput {
            do {
                audioInput = try AVCaptureDeviceInput(device: input)
                
                if session!.canAddInput(audioInput!) {
                    session!.addInput(audioInput!)
                    targetAudioInput = audioInput
                    AwesomeVisualMessage(.Info, info: "Audio input added.")
                    return true
                }
                
            } catch {
                AwesomeVisualMessage(.Warn, info: "Audio input create fail.")
            }
            
            audioInput = nil
            AwesomeVisualMessage(.Warn, info: "Audio input added fail.")
            return false
        }
        
        if input == audioInput!.device {
            return true
            
        } else {
            deinitAudioInput()
        }
        
        return initAudioInput(input)
    }
    
    private func deinitAudioInput() {
        if nil != audioInput {
            session!.removeInput(audioInput)
            audioInput = nil
            AwesomeVisualMessage(.Info, info: "Audio input removed.")
        }
    }
    
    private func initVideoOutput(output: AVCaptureVideoDataOutput) -> Bool {
        if nil == videoOutput {
            if session!.canAddOutput(output) {
                // configure output
                videoOutput = output
                videoOutput!.setSampleBufferDelegate(self, queue: AwesomeVisual.awesomeVisualVideoQueue)
                videoOutput!.videoSettings = _delegate?.settingsOutputVideo?(self) ?? settingsOutputVideo(self)
                videoOutput!.alwaysDiscardsLateVideoFrames = false
                session!.addOutput(videoOutput!)
                targetVideoOutput = videoOutput
                AwesomeVisualMessage(.Info, info: "Video Output added.")
                return true
            }
        }
        
        videoOutput = nil
        AwesomeVisualMessage(.Warn, info: "Video Output added fail.")
        return false
    }
    
    private func deinitVideoOutput() {
        if nil != videoOutput {
            session!.removeOutput(videoOutput!)
            videoOutput = nil
            AwesomeVisualMessage(.Info, info: "Video Output removed.")
        }
    }
    
    private func initAudioOutput(output: AVCaptureAudioDataOutput) -> Bool {
        if nil == audioOutput {
            if session!.canAddOutput(output) {
                audioOutput = output
                audioOutput!.setSampleBufferDelegate(self, queue: AwesomeVisual.awesomeVisualVideoQueue/*awesomeVisualAudioQueue*/)
                session!.addOutput(audioOutput)
                targetAudioOutput = audioOutput
                AwesomeVisualMessage(.Info, info: "Audio Output added.")
                return true
            }
        }
        
        audioOutput = nil
        AwesomeVisualMessage(.Warn, info: "Audio Output added fail.")
        return false
    }
    
    private func deinitAudioOutput() {
        if nil != audioOutput {
            session!.removeOutput(audioOutput!)
            audioOutput = nil
            AwesomeVisualMessage(.Info, info: "Audio Output removed.")
        }
    }
    
    private func initOriginalPreview(frame: CGRect) {
        if nil == previewLayer {
            containerView = UIView(frame: frame)
            previewLayer = AVCaptureVideoPreviewLayer()
            previewLayer!.session = session!
            previewLayer!.frame = containerView!.layer.bounds
            previewLayer!.videoGravity = videoGravity // 设置预览时的视频缩放方式
            previewLayer!.connection.videoOrientation = videoOrientation // 设置视频的朝向
            containerView!.layer.addSublayer(previewLayer!)
            AwesomeVisualMessage(.Info, info: "Original preview initialized.")
            return
        }
        
        containerView!.frame = frame
        previewLayer!.frame = containerView!.layer.bounds
    }
    
    private func deinitOriginalPreview() {
        if nil != previewLayer {
            previewLayer!.removeFromSuperlayer()
            containerView!.removeFromSuperview()
            containerView = nil
            previewLayer = nil
            AwesomeVisualMessage(.Info, info: "Original preview deinitialized.")
        }
    }
    
    private func addObservers() {
        guard !observerIsAdded else {
            return
        }
        
        session!.addObserver(self, forKeyPath: "running", options: NSKeyValueObservingOptions.New, context: sessionRunningContext)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(subjectAreaDidChange), name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: self.videoInput!.device)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(sessionRuntimeError), name: AVCaptureSessionRuntimeErrorNotification, object: self.session)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(sessionWasInterrupted), name: AVCaptureSessionWasInterruptedNotification, object: self.session)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(sessionInterruptionEnded), name: AVCaptureSessionInterruptionEndedNotification, object: self.session)
        observerIsAdded = true
        AwesomeVisualMessage(.Info, info: "Observer added.")
    }
    
    private func removeObservers() {
        guard observerIsAdded else {
            return
        }
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
        session!.removeObserver(self, forKeyPath: "running", context: UnsafeMutablePointer<Void>(sessionRunningContext))
        observerIsAdded = false
        AwesomeVisualMessage(.Info, info: "Observer removed.")
    }
    
    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == sessionRunningContext {
            AwesomeVisualMessage(.Debug, info: "Value for key sessionRunningContext change \(isSessionRunning)")
            
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    private func focusWithMode(focuseMode: AVCaptureFocusMode, forDevice device: AVCaptureDevice, exposeWithMode exposureMode: AVCaptureExposureMode, atDevicePoint point: CGPoint, monitorSubjectAreaChange subjectAreaChange: Bool) {
        
        if !subjectAreaChange && (subjectAreaChange == device.subjectAreaChangeMonitoringEnabled) {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if device.focusPointOfInterestSupported && device.isFocusModeSupported(focuseMode) {
                device.focusPointOfInterest = point
                device.focusMode = focuseMode
            }
            
            if device.smoothAutoFocusSupported {
                device.smoothAutoFocusEnabled = true
            }
            
            if device.lowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            
            if device.exposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                device.exposurePointOfInterest = point
                device.exposureMode = exposureMode
            }
            
            device.subjectAreaChangeMonitoringEnabled = subjectAreaChange
            device.unlockForConfiguration()
            
        } catch {
            AwesomeVisualMessage(.Warn, info: "Device configuration can not be locked.")
        }
    }
    
    private func setFlashMode(flashMode: AVCaptureFlashMode, forDevice device: AVCaptureDevice) {
        if device.hasFlash && device.isFlashModeSupported(flashMode) {
            do {
                try device.lockForConfiguration()
                
                device.flashMode = flashMode
                switch  device.flashMode {
                case .Auto:
                    device.torchMode = .Auto
                case .On:
                    device.torchMode = .On
                case .Off:
                    device.torchMode = .Off
                }

                device.unlockForConfiguration()
                
            } catch {
                AwesomeVisualMessage(.Warn, info: "Device configuration can not be locked.")
            }
        }
    }
    
    private func prepareSession(complete: ((AwesomeVisual) -> Void)?) -> Bool {
        guard nil != session else {
            AwesomeVisualMessage(.Warn, info: "No session setted.")
            return false
        }
        
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            let outputVideoFormat: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
            let outputAudioFormat: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
            strongSelf.session!.beginConfiguration()
            if !(strongSelf.initVideoInput(strongSelf.videoInputDevice!) && strongSelf.initAudioInput(strongSelf.audioInputDevice!) && strongSelf.initVideoOutput(outputVideoFormat) && strongSelf.initAudioOutput(outputAudioFormat)) {
                strongSelf.mediaStat = .Error
            }
            
            if strongSelf.mediaStat != .Authorized {
                strongSelf.unprepareSession()
                
            } else {
                // MARK: session configure
                if strongSelf._delegate?.configSession != nil {
                    strongSelf._delegate?.configSession!(strongSelf, session: strongSelf.session!)
                } else {
                    strongSelf.configSession(strongSelf, session: strongSelf.session!)
                }
                
                strongSelf.mediaStat = .Success
            }
            
            // MAKR: video input configure
            do {
                try strongSelf.videoInput!.device.lockForConfiguration()
                if nil != strongSelf._delegate?.configInputVideoDeviceBeforeRunning {
                    strongSelf._delegate?.configInputVideoDeviceBeforeRunning!(strongSelf, device: strongSelf.videoInput!.device, withConnection: outputVideoFormat.connectionWithMediaType(AVMediaTypeVideo))
                } else {
                    strongSelf.configInputVideoDeviceBeforeRunning(strongSelf, device: strongSelf.videoInput!.device, withConnection: outputVideoFormat.connectionWithMediaType(AVMediaTypeVideo))
                }
                strongSelf.videoInput!.device.unlockForConfiguration()
                
            } catch {
                AwesomeVisualMessage(.Warn, info: "Video input configure error.")
            }
            
            // MARK: audio input configure
            do {
                try strongSelf.audioInput!.device.lockForConfiguration()
                if nil != strongSelf.delegate?.configInputAudioDeviceBeforeRunning {
                    strongSelf._delegate?.configInputAudioDeviceBeforeRunning!(strongSelf, device: strongSelf.audioInput!.device, withConnection: outputAudioFormat.connectionWithMediaType(AVMediaTypeAudio))
                } else {
                    strongSelf.configInputAudioDeviceBeforeRunning(strongSelf, device: strongSelf.audioInput!.device, withConnection: outputAudioFormat.connectionWithMediaType(AVMediaTypeAudio))
                    
                }
                strongSelf.videoInput!.device.unlockForConfiguration()
                
            } catch {
                AwesomeVisualMessage(.Warn, info: "Audio input configure error.")
            }
            
            strongSelf.session!.commitConfiguration()
            
            // add observers
            strongSelf.addObservers()
            
            dispatch_async(dispatch_get_main_queue()) {
                complete?(strongSelf)
            }
        }
        
        AwesomeVisualMessage(.Info, info: "Media session configure success.")
        return true
    }
    
    private func unprepareSession() {
        stopCapture(nil)
        removePreviewLayer()
        removeObservers()
        deinitVideoInput()
        deinitAudioInput()
        deinitVideoOutput()
        deinitAudioOutput()
        AwesomeVisualMessage(.Info, info: "Media session deinited.")
    }
    
    private func processSessionStart(didStart: ((AwesomeVisual) -> Void)?) {
        session!.startRunning()
        
        if nil != didStart {
            dispatch_async(dispatch_get_main_queue()) {
                [weak self] in
                if let strongSelf = self {
                    didStart!(strongSelf)
                }
            }
        }
    }
    
    private func processSessionStop(didStop: ((AwesomeVisual) -> Void)?) {
        recorder?.preferRecordStop(true, complete: nil)
        session!.stopRunning()
        
        if nil != didStop {
            dispatch_async(dispatch_get_main_queue()) {
                [weak self] in
                if let strongSelf = self {
                    didStop!(strongSelf)
                }
            }
        }
    }
}


// MARK: - Notification Callback

extension AwesomeVisual {
    
    func subjectAreaDidChange(notification: NSNotification) {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            strongSelf.focusWithMode(AVCaptureFocusMode.ContinuousAutoFocus, forDevice: strongSelf.targetVideoInput!.device, exposeWithMode: AVCaptureExposureMode.ContinuousAutoExposure, atDevicePoint: CGPointMake(0.5, 0.5), monitorSubjectAreaChange: false)
        }
    }
    
    func sessionRuntimeError(notification: NSNotification) {
        let error = notification.userInfo![AVCaptureSessionErrorKey]
        AwesomeVisualMessage(.Error, info: "Capture session runtime error: \(error)")
        
        if AVError(rawValue: error!.code) == AVError.MediaServicesWereReset {
            let strongSelf = self
            AwesomeVisual.dispatchInVideoQueue {
                if strongSelf.isSessionRunning {
                    strongSelf.session!.startRunning()
                }
            }
        }
    }
    
    func sessionWasInterrupted(notification: NSNotification) {
        AwesomeVisualMessage(.Warn, info: "Session was interruptted")
    }
    
    func sessionInterruptionEnded(notification: NSNotification) {
        AwesomeVisualMessage(.Warn, info: "Session interruption ended")
    }
}


// MARK: - SampleBuffer Delegate

extension AwesomeVisual {
    
    public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if let record = recorder {
            record.captureRecordProcess(captureOutput, didOutputSampleBuffer: sampleBuffer/*, fromConnection: connection*/)
        }
    }
    
    public func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    }
}


// MARK: AwesomeVisual Delegate 

extension AwesomeVisual {
    
    /// session configuration
    // may not be called if using GPUImage
    public func configSession(awesomeVisual: AwesomeVisual, session: AVCaptureSession) {
        if session.canSetSessionPreset(AVCaptureSessionPresetHigh) {
            session.sessionPreset = AVCaptureSessionPresetHigh
        }
    }
    
    /// video device configuration
    // may not be called if using GPUImage
    public func configInputVideoDeviceBeforeRunning(awesomeVisual: AwesomeVisual, device: AVCaptureDevice, withConnection connection: AVCaptureConnection?) {
        if nil != connection && device.activeFormat.isVideoStabilizationModeSupported(AVCaptureVideoStabilizationMode.Cinematic) {
            connection!.preferredVideoStabilizationMode = .Cinematic
        }
    }
    
    /// audio device configuration
    // may not be called if using GPUImage
    public func configInputAudioDeviceBeforeRunning(awesomeVisual: AwesomeVisual, device: AVCaptureDevice, withConnection connection: AVCaptureConnection?) {
    }
    
    /// settings for video output
    // may not be called if using GPUImage
    public func settingsOutputVideo(awesomeVisual: AwesomeVisual) -> [NSObject : AnyObject] {
        return [
            kCVPixelBufferPixelFormatTypeKey : NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)
        ]
    }
    
    public func shouldEneableAssetWriter(awesomeVisual: AwesomeVisual) -> Bool {
        return true
    }
    
    public func shouldEnableMergeAssetWriter(awesomeVisual: AwesomeVisual) -> Bool {
        return true
    }
    
}


