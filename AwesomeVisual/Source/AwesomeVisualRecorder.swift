//
// AwesomeVisualRecorder.swift
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

import Foundation
import AVFoundation
import GPUImage


// MAKR: - AwesomeVisualRecorderDelegate

/**
 *  AwesomeVisualRecorderDelegate
 */
@objc
public protocol AwesomeVisualRecorderDelegate: NSObjectProtocol {
    
    func assetWriterFileURL(recorder: AwesomeVisualRecorder) -> NSURL?
    
    optional func assetWriterMergedFileURL(recorder: AwesomeVisualRecorder) -> NSURL?
    
    optional func settingsForVideoWriterInput(recorder: AwesomeVisualRecorder, description: CMFormatDescription?, videoSize: CGSize) -> [String : AnyObject]?
    
    optional func settingsForVideoWriterInputPixelBufferAdaptor(recorder: AwesomeVisualRecorder, description: CMFormatDescription?) -> [String : AnyObject]?
    
    optional func settingsForAudioWriterInput(recorder: AwesomeVisualRecorder, description: CMFormatDescription?) -> [String : AnyObject]?
    
    // life cycle
    optional func willBeginRecord(recorder: AwesomeVisualRecorder)
    
    optional func didBeginRecord(recorder: AwesomeVisualRecorder)
    
    optional func willEndRecord(recorder: AwesomeVisualRecorder)
    
    optional func didEndRecord(recorder: AwesomeVisualRecorder)
    
    optional func whenStart(recorder: AwesomeVisualRecorder)
    
    optional func whenPause(recorder: AwesomeVisualRecorder)
    
    optional func whenResume(recorder: AwesomeVisualRecorder)
    
    optional func whenStop(recorder: AwesomeVisualRecorder)
}


// MARK: - AssetWriterInputStatu

/**
 AssetWriterInput statu.
 
 - Ready:   AssetWriterInput is ready.
 - Fail:    AssetWriterInput is init fail.
 - Useful:  AssetWriterInput is useful.
 - Unknown: AssetWriterInput is unknown.
 */
enum AssetWriterInputStatu {
    case Ready
    case Fail
    case Useful
    case Unknown
}


// MARK: - AwesomeVisualRecorder

public class AwesomeVisualRecorder: NSObject, AwesomeVisualRecorderDelegate {
    
    // asset writer
    private weak var _delegate: AwesomeVisualRecorderDelegate?
    private unowned let awesomeVisual: AwesomeVisual
    private var fileAssetWriteFileURL: NSURL?
    private var fileAssetWriter: AVAssetWriter?
    private var fileAssetVideoInput: AVAssetWriterInput?
    private var fileAssetAudioInput: AVAssetWriterInput?
    private var fileAssetVideoInputAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var fileAssetVideoInputStatu: AssetWriterInputStatu = .Unknown
    private var fileAssetAudioInputStatu: AssetWriterInputStatu = .Unknown
    private var fileAssetLastVideoSampleBuffer: CMSampleBuffer?
    private var fileAssetLastAudioSampleBuffer: CMSampleBuffer?
    private var fileSegmentStartTime: CMTime = kCMTimeInvalid
    private var fileSegmentTimeOffset: CMTime = kCMTimeZero
    private var fileSegmentVideoEndTime: CMTime = kCMTimeInvalid
    private var fileSegmentAudioEndTime: CMTime = kCMTimeInvalid
    private var fileSegmentHasVideo = false
    private var fileSegmentHasAudio = false
    private var fileAssetWriterInitFail = false
    private var lastRecordAppendSampleState = false
    private var recordNeededAppendSample = false
    private var recordNeededStop = false
    private var recordNeededStopStack: (Bool, ((index: Int) -> Void)?)?
    private var assetOutputAssets = [AVURLAsset]()
    private var recordVideoDescription: CMFormatDescription?
    private var recordAudioDescription: CMFormatDescription?
    private var recordVideoSettings: [String : AnyObject]?
    private var recordAudioSettings: [String : AnyObject]?
    private var gpuImageRawDataOutput: GPUImageRawOutputForAwesomeVisual?
    
    
    public init(visual: AwesomeVisual) {
        awesomeVisual = visual
        super.init()
        _delegate = self
        AwesomeVisualMessage(.Info, info: "AwesomeVisualRecorder inited.")
    }
    
    deinit {
        removeAllOutputAsset()
        AwesomeVisualMessage(.Info, info: "AwesomeVisualRecorder deinited.")
    }
    
    public subscript(index: Int) -> AVURLAsset? {
        guard index > -1 && index < assetOutputAssets.count else {
            return nil
        }
        
        return assetOutputAssets[index]
    }
    
    let newFrameAvailableBlockForGPUImage: () -> Void = {
        
    }
}


// MARK: - Public Method

extension AwesomeVisualRecorder {
    
    public weak var delegate: AwesomeVisualRecorderDelegate? {
        set {
            if nil != newValue {
                _delegate = newValue
            }
        }
        
        get {
            return nil
        }
    }
    
    public var isRecording: Bool {
        return recordNeededAppendSample
        
    }
    
    public var isProcessing: Bool {
        return nil != fileAssetWriter
    }
    
    public var videoSettings: [String : AnyObject]? {
        return recordVideoSettings
    }
    
    public var audioSettings: [String : AnyObject]? {
        return recordAudioSettings
    }
    
    public var videoDescription: CMFormatDescription? {
        return recordVideoDescription
    }
    
    public var audioDescription: CMFormatDescription? {
        return recordAudioDescription
    }
    
    public var outputAssetCount: Int {
        return assetOutputAssets.count
    }
    
    public func preferRecordStart() {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            if !strongSelf.isProcessing && !strongSelf.recordNeededAppendSample && !strongSelf.recordNeededStop {
                strongSelf.recordNeededAppendSample = true
                AwesomeVisualMessage(.Debug, info: "Prefer record start.")
            }
        }
    }
    
    public func preferRecordResume() {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            if strongSelf.isProcessing && !strongSelf.recordNeededAppendSample && !strongSelf.recordNeededStop {
                strongSelf.recordNeededAppendSample = true
                AwesomeVisualMessage(.Debug, info: "Prefer record resume.")
            }
        }
    }
    
    public func preferRecordPause() {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            if strongSelf.isProcessing && strongSelf.recordNeededAppendSample && !strongSelf.recordNeededStop {
                strongSelf.recordNeededAppendSample = false
                AwesomeVisualMessage(.Debug, info: "Prefer record pause.")
            }
        }
    }
    
    public func preferRecordStop(isCancel: Bool, complete: ((index: Int) -> Void)?) {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            if strongSelf.isProcessing && !strongSelf.recordNeededStop {
                strongSelf.recordNeededStop = true
                strongSelf.recordNeededStopStack = (isCancel, complete)
                AwesomeVisualMessage(.Debug, info: "Prefer record stop.")
            }
        }
    }
    
    public func captureRecordProcess(captureOutput: AVCaptureOutput, didOutputSampleBuffer sampleBuffer: CMSampleBuffer/*, fromConnection connection: AVCaptureConnection*/) {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            if captureOutput == strongSelf.awesomeVisual.targetVideoOutput {
                strongSelf.fileAssetLastVideoSampleBuffer = sampleBuffer
                strongSelf.processVideoSampleBuffer(sampleBuffer/*, fromConnection: connection*/)
                
            } else {
                strongSelf.fileAssetLastAudioSampleBuffer = sampleBuffer
                strongSelf.processAudioSampleBuffer(sampleBuffer)
            }
            
            if nil != strongSelf.fileAssetWriter && strongSelf.recordNeededStop {
                if let (cancel, complete) = strongSelf.recordNeededStopStack {
                    strongSelf.recordNeededStopStack = nil
                    strongSelf.recordNeededAppendSample = false
                    strongSelf.lastRecordAppendSampleState = false
                    strongSelf.processRecordEnd(shouldCancel: cancel, complete: complete)
                }
                
                return
            }
            
            if strongSelf.recordNeededAppendSample != strongSelf.lastRecordAppendSampleState {
                // recording
                if strongSelf.recordNeededAppendSample {
                    if strongSelf.fileSegmentHasVideo || strongSelf.fileSegmentHasAudio {
                        let lastEndTime = 0 < CMTimeCompare(strongSelf.fileSegmentVideoEndTime, strongSelf.fileSegmentAudioEndTime) ? strongSelf.fileSegmentVideoEndTime : strongSelf.fileSegmentAudioEndTime
                        strongSelf.fileSegmentTimeOffset = CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), lastEndTime)
                        AwesomeVisualMessage(.Debug, info: "Offset \(strongSelf.fileSegmentTimeOffset)")
                    }
                    
                    if kCMTimeZero != strongSelf.fileSegmentTimeOffset {
                        dispatch_async(dispatch_get_main_queue()) {
                            strongSelf._delegate?.whenResume?(strongSelf)
                        }
                    }
                    
                } else {
                    // pause
                    dispatch_async(dispatch_get_main_queue()) {
                        strongSelf._delegate?.whenPause?(strongSelf)
                    }
                }
            }
            
            strongSelf.lastRecordAppendSampleState = strongSelf.recordNeededAppendSample
        }
    }
    
    public func removeRecordAssetAtIndex(index: Int) {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            strongSelf.removeOutputAssetAtIndex(index)
        }
    }
    
    public func removeAllRecordAsset() {
        let strongSelf = self
        AwesomeVisual.dispatchInVideoQueue {
            strongSelf.removeAllOutputAsset()
        }
    }
}


// MARK: Private Method

extension AwesomeVisualRecorder {
    
    private func assetWriter() -> AVAssetWriter? {
        fileAssetWriteFileURL = _delegate?.assetWriterFileURL(self)
        
        if let url = fileAssetWriteFileURL {
            var writer: AVAssetWriter?
            
            if NSFileManager.defaultManager().fileExistsAtPath(fileAssetWriteFileURL!.path!) {
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(url)
                } catch _ {}
            }
            
            do {
                writer = try AVAssetWriter(URL: url, fileType: AVFileTypeMPEG4)
                AwesomeVisualMessage(.Debug, info: "AwesomeVisual Recorder created.")
                return writer
                
            } catch {
                AwesomeVisualMessage(.Error, info: "AssetWrite create fail [\(error)].")
            }
        }
        
        return nil
    }
    
    private func createAssetWriter() -> Bool {
        fileAssetWriter = assetWriter()
        
        if nil == fileAssetWriter || .Unknown != fileAssetWriter!.status {
            AwesomeVisualMessage(.Error, info: "AssetWrite init fail.")
            return false
        }
        
        if .Useful == fileAssetVideoInputStatu {
            if fileAssetWriter!.canAddInput(fileAssetVideoInput!) {
                fileAssetWriter!.addInput(fileAssetVideoInput!)
                fileAssetVideoInputStatu = .Ready
                AwesomeVisualMessage(.Debug, info: "AssetWrite video input added.")
                
            } else {
                fileAssetVideoInputStatu = .Fail
                AwesomeVisualMessage(.Warn, info: "AssetWrite video input add fail.")
            }
            
        } else {
            AwesomeVisualMessage(.Warn, info: "AssetWrite has no video input.")
        }
        
        if .Useful == fileAssetAudioInputStatu {
            if fileAssetWriter!.canAddInput(fileAssetAudioInput!) {
                fileAssetWriter!.addInput(fileAssetAudioInput!)
                fileAssetAudioInputStatu = .Ready
                AwesomeVisualMessage(.Debug, info: "AssetWrite audio input added.")
                
            } else {
                fileAssetAudioInputStatu = .Fail
                AwesomeVisualMessage(.Warn, info: "AssetWrite audio input add fail.")
            }
            
        } else {
            AwesomeVisualMessage(.Warn, info: "AssetWrite has no audio input.")
        }
        
        fileSegmentStartTime = kCMTimeInvalid
        fileSegmentVideoEndTime = fileSegmentStartTime
        fileSegmentAudioEndTime = fileSegmentStartTime
        fileSegmentTimeOffset = kCMTimeZero
        if nil != _delegate?.whenStart {
            let strongSelf = self
            dispatch_async(dispatch_get_main_queue()) {
                strongSelf._delegate!.whenStart!(strongSelf)
            }
        }
        return true
    }
    
    private func destroyAssetWriter() {
        
        if nil != fileAssetWriter {
            destroyAssetWriteVideoInput()
            destroyAssetWriteAudioInput()
            fileAssetWriter = nil
            fileAssetWriterInitFail = false
            fileAssetLastVideoSampleBuffer = nil
            fileAssetLastAudioSampleBuffer = nil
            recordNeededStop = false
            recordNeededStopStack = nil
            if nil != _delegate?.whenStop {
                let strongSelf = self
                dispatch_async(dispatch_get_main_queue()) {
                    strongSelf._delegate!.whenStop!(strongSelf)
                }
            }
            AwesomeVisualMessage(.Debug, info: "AwesomeVisual Recorder destroyed.")
        }
    }
    
    private func checkVideoSettings() {
        if nil == recordVideoSettings {
            recordVideoSettings = [String : AnyObject]()
        }
        
        if recordVideoSettings![AVVideoCodecKey] == nil {
            recordVideoSettings![AVVideoCodecKey] = AVVideoCodecH264
        }
        
        if recordVideoSettings![AVVideoWidthKey] == nil {
            recordVideoSettings![AVVideoWidthKey] = 1280
        }
        
        if recordVideoSettings![AVVideoHeightKey] == nil {
            recordVideoSettings![AVVideoHeightKey] = 720
        }
    }
    
    private func createAssetWriteVideoInputIfNeeded(sampleBuffer: CMSampleBuffer) {
        
        if fileAssetVideoInputStatu == .Unknown && nil == fileAssetVideoInput && !fileAssetWriterInitFail {
            var videoSize = CGSizeZero
            if let imageSample = CMSampleBufferGetImageBuffer(sampleBuffer) {
                videoSize = CGSizeMake(CGFloat(CVPixelBufferGetWidth(imageSample)), CGFloat(CVPixelBufferGetHeight(imageSample)))
            }
            
            if nil == recordVideoSettings {
                let sampleDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
                recordVideoSettings = _delegate?.settingsForVideoWriterInput?(self, description: sampleDescription, videoSize: videoSize)
                checkVideoSettings()
                recordVideoDescription = sampleDescription
            }
            
            fileAssetVideoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: recordVideoSettings!, sourceFormatHint: recordVideoDescription!)
            fileAssetVideoInput!.expectsMediaDataInRealTime = true
            /**
             由于录制时坐标系以左向横屏时（home键在右边）为基础，所以输出需要进行旋转。
             */
            if awesomeVisual.type != .GPUImage {
                fileAssetVideoInput!.transform = CGAffineTransformMakeRotation(CGFloat(M_PI / 2))
            }
            
            let pixelBufferAttributes = _delegate?.settingsForVideoWriterInputPixelBufferAdaptor?(self, description: recordVideoDescription!) ?? settingsForVideoWriterInputPixelBufferAdaptor(self, description: recordVideoDescription!)
            fileAssetVideoInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: fileAssetVideoInput!, sourcePixelBufferAttributes: pixelBufferAttributes)
            fileAssetVideoInputStatu = .Useful
            fileSegmentHasVideo = false
            AwesomeVisualMessage(.Debug, info: "AssetWrite Video input inited.")
        }
    }
    
    private func destroyAssetWriteVideoInput() {
        if nil != fileAssetVideoInput {
            fileAssetVideoInput = nil
            fileAssetVideoInputAdaptor = nil
            fileAssetVideoInputStatu = .Unknown
            fileSegmentHasVideo = false
            AwesomeVisualMessage(.Debug, info: "AssetWrite Video input destroyed.")
        }
    }
    
    private func checkAudioSettings() {
        if nil == recordAudioSettings {
            recordAudioSettings = [String : AnyObject]()
        }
        
        if nil == recordAudioSettings![AVFormatIDKey] {
            recordAudioSettings![AVFormatIDKey] = NSNumber(unsignedInt: kAudioFormatMPEG4AAC)
        }
        
        if nil == recordAudioSettings![AVNumberOfChannelsKey] {
            recordAudioSettings![AVNumberOfChannelsKey] = 1
        }
        
        if nil == recordAudioSettings![AVSampleRateKey] {
            recordAudioSettings![AVSampleRateKey] = AVAudioSession.sharedInstance().sampleRate
        }
    }
    
    private func createAssetWriteAudioInputIfNeeded(sampleBuffer: CMSampleBuffer) {
        
        if fileAssetAudioInputStatu == .Unknown && nil == fileAssetAudioInput && !fileAssetWriterInitFail {
            
            if nil == recordAudioSettings {
                let sampleDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
                recordAudioSettings = _delegate?.settingsForAudioWriterInput?(self, description: sampleDescription) 
                recordAudioDescription = sampleDescription
            }
            
            fileAssetAudioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: recordAudioSettings!, sourceFormatHint: recordAudioDescription!)
            fileAssetAudioInput!.expectsMediaDataInRealTime = true
            fileAssetAudioInputStatu = .Useful
            fileSegmentHasAudio = false
            AwesomeVisualMessage(.Debug, info: "AssetWrite audio input inited.")
        }
    }
    
    private func destroyAssetWriteAudioInput() {
        if nil != fileAssetAudioInput {
            fileAssetAudioInput = nil
            fileAssetAudioInputStatu = .Unknown
            fileSegmentHasAudio = false
            AwesomeVisualMessage(.Debug, info: "AssetWrite Audio input destroyed.")
        }
    }
    
    private func processRecordStart() -> Bool {
        if nil != fileAssetWriter {
            AwesomeVisualMessage(.Warn, info: "Record session has already started.")
            return false
        }
        
        let strongSelf = self
        dispatch_async(dispatch_get_main_queue()) {
            strongSelf._delegate?.willBeginRecord?(strongSelf)
        }
        
        if createAssetWriter() {
            if fileAssetWriter!.startWriting() && .Writing == fileAssetWriter!.status {
                AwesomeVisualMessage(.Debug, info: "Record session start.")
                dispatch_async(dispatch_get_main_queue()) {
                    strongSelf._delegate?.didBeginRecord?(strongSelf)
                }
                return true
            }
            
            AwesomeVisualMessage(.Warn, info: "Record session start fail [\(fileAssetWriter!.error)]. ")
        }
        
        destroyAssetWriter()
        preferRecordStop(true, complete: nil)
        fileAssetWriterInitFail = true
        AwesomeVisualMessage(.Warn, info: "Record session init fail.")
        return false
    }
    
    private func processRecordEnd(shouldCancel cancel: Bool, complete: ((index: Int) -> Void)?) -> Bool {
        if nil != fileAssetWriter {
            let strongSelf = self
            dispatch_async(dispatch_get_main_queue()) {
                strongSelf._delegate?.willEndRecord?(strongSelf)
            }
            
            if cancel || fileAssetWriter!.status != .Writing {
                let url = fileAssetWriter!.outputURL
                fileAssetWriter!.cancelWriting()
                destroyAssetWriter()
                AwesomeVisualMessage(.Debug, info: "Record session end.")
                
                if NSFileManager.defaultManager().fileExistsAtPath(url.path!) {
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(url.path!)
                        
                    } catch _ {}
                }
                
                dispatch_async(dispatch_get_main_queue()) {
                    strongSelf._delegate?.didEndRecord?(strongSelf)
                    complete?(index: -1)
                }
                
            } else {
                var endTime = fileSegmentStartTime
                
                if CMTIME_IS_VALID(fileSegmentVideoEndTime) {
                    endTime = fileSegmentVideoEndTime
                }
                
                if CMTIME_IS_VALID(fileSegmentAudioEndTime) {
                    endTime = 0 < CMTimeCompare(endTime, fileSegmentAudioEndTime) ? endTime : fileSegmentAudioEndTime
                }
                
                if CMTIME_IS_VALID(endTime) {
                    fileAssetWriter!.endSessionAtSourceTime(endTime)
                }
                
                let unownedSelf = self
                fileAssetWriter!.finishWritingWithCompletionHandler {
                    AwesomeVisual.dispatchInVideoQueue {
                        // when finished, append the new segment to asset array.
                        let index = unownedSelf.appendOutputAsset(unownedSelf.fileAssetWriter!.outputURL)
                        unownedSelf.destroyAssetWriter()
                        AwesomeVisualMessage(.Debug, info: "Record session end.")
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            unownedSelf._delegate?.didEndRecord?(unownedSelf)
                            complete?(index: index)
                        }
                    }
                }
            }
            
            return true
        }
        
        return false
    }
    
    /**
     Append a new asset with url to assetOutPutAssets.
     
     - parameter url: Asset url.
     
     - returns: Index that the new append at, and return -1 if the asset not available.
     */
    private func appendOutputAsset(url: NSURL) -> Int {
        var i: Int?
        for (index, item) in assetOutputAssets.enumerate() {
            if item.URL == url {
                i = index
                break
            }
        }
        
        let asset = AVURLAsset(URL: url)
        if asset.readable {
            if nil != i {
                assetOutputAssets[i!] = asset
                
            } else {
                assetOutputAssets.append(asset)
                i = assetOutputAssets.count - 1
            }
            
            AwesomeVisualMessage(.Debug, info: "Asset insert at \(i!) [\(url)].")
            
        } else {
            if nil != i {
                assetOutputAssets.removeAtIndex(i!)
                
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(url)
                    
                } catch {
                    AwesomeVisualMessage(.Error, info: "Asset remove inavailable fail [\(error)].")
                }
            }
            
            i = -1
            AwesomeVisualMessage(.Error, info: "Asset at \(url) is not available [\(url)].")
        }
        
        return i!
    }
    
    private func removeOutputAssetAtIndex(index: Int) {
        guard index > -1 && index < assetOutputAssets.count else {
            return
        }
        
        let url = assetOutputAssets[index].URL
        
        do {
            assetOutputAssets.removeAtIndex(index)
            try NSFileManager.defaultManager().removeItemAtURL(url)
            AwesomeVisualMessage(.Debug, info: "Remove asset at index \(index) [\(url)].")
            
        } catch {
            AwesomeVisualMessage(.Error, info: "Remove asset at index \(index) fail [\(url) => \(error)].")
        }
    }
    
    private func removeAllOutputAsset() {
        let count = assetOutputAssets.count
        for _ in 0..<count {
            removeOutputAssetAtIndex(assetOutputAssets.count - 1)
        }
        
        AwesomeVisualMessage(.Debug, info: "Remove all assets.")
    }
    
    /**
     From  http://www.gdcl.co.uk/2013/02/20/iPhone-Pause.html
     */
    private func adjustBuffer(sampleBuffer: CMSampleBuffer, withTimeOffset timeOffset: CMTime, andDuration duration: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &count)
        var pInfo: [CMSampleTimingInfo] = [CMSampleTimingInfo](count: count, repeatedValue: CMSampleTimingInfo())
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, count, &pInfo, &count)
        
        for i in 0..<pInfo.count {
            pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, timeOffset)
            pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, timeOffset)
            pInfo[i].duration = duration
        }
        
        var newBuffer: CMSampleBuffer? = nil
        let err = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, count, pInfo, &newBuffer)
        return (0 == err) ? newBuffer : nil
    }
    
    private func setSegmentStartTimeIfNeeded(time: CMTime) -> Bool {
        if CMTIME_IS_INVALID(fileSegmentStartTime) {
            fileSegmentStartTime = time
            fileAssetWriter!.startSessionAtSourceTime(fileSegmentStartTime)
            return true
        }
        
        return false
    }
    
    private func appendVideoSampleBuffer(sampleBuffer: CMSampleBuffer, withDuration duration: CMTime, isFirstBuffer first: Bool) {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if first {
            if setSegmentStartTimeIfNeeded(presentationTime) {
                fileSegmentVideoEndTime = fileSegmentStartTime
                
            } else {
                fileSegmentVideoEndTime = CMTimeSubtract(presentationTime, fileSegmentTimeOffset)
            }
        }
        
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            if fileAssetVideoInput!.readyForMoreMediaData && fileAssetVideoInputAdaptor!.appendPixelBuffer(imageBuffer, withPresentationTime: fileSegmentVideoEndTime) {
                fileSegmentVideoEndTime = CMTimeAdd(fileSegmentVideoEndTime, duration)
                fileSegmentHasVideo = true
            }
        }
    }
    
    private func appendAudioSampleBuffer(sampleBuffer: CMSampleBuffer, withDuration duration: CMTime, isFirstBuffer first: Bool) {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if first {
            if setSegmentStartTimeIfNeeded(presentationTime) {
                fileSegmentAudioEndTime = fileSegmentStartTime
                
            } else {
                fileSegmentAudioEndTime = CMTimeSubtract(presentationTime, fileSegmentTimeOffset)
            }
        }
        
        let strongSelf = self
        AwesomeVisual.dispatchInAudioQueue {
            if let newBuffer = strongSelf.adjustBuffer(sampleBuffer, withTimeOffset: strongSelf.fileSegmentTimeOffset, andDuration: duration) {
                if strongSelf.fileAssetAudioInput!.readyForMoreMediaData && strongSelf.fileAssetAudioInput!.appendSampleBuffer(newBuffer) {
                    dispatch_async(AwesomeVisual.awesomeVisualVideoQueue) {
                        strongSelf.fileSegmentAudioEndTime = CMTimeAdd(strongSelf.fileSegmentAudioEndTime, duration)
                        strongSelf.fileSegmentHasAudio = true
                    }
                }
            }
        }
    }
    
    private func processVideoSampleBuffer(sampleBuffer: CMSampleBuffer/*, fromConnection connection: AVCaptureConnection*/) {
        
        // record
        if recordNeededAppendSample {
            // create assetWriterVideoInput
            createAssetWriteVideoInputIfNeeded(sampleBuffer)
            
            // assetWriterAudioInput has been inited
            if .Unknown != fileAssetAudioInputStatu {
                // init assetWriter
                if nil == fileAssetWriter && !fileAssetWriterInitFail {
                    processRecordStart()
                }
                
                if !fileAssetWriterInitFail {
                    let duration = awesomeVisual.targetVideoInput!.device.activeVideoMaxFrameDuration
                    appendVideoSampleBuffer(sampleBuffer, withDuration: duration, isFirstBuffer: !fileSegmentHasVideo)
                    // if the sample is the first video sample and the time of this sample early than the last audio sample, process it
                    if !fileSegmentHasVideo && .Unknown != fileAssetAudioInputStatu && nil != fileAssetLastAudioSampleBuffer {
                        if 0 > CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), CMSampleBufferGetPresentationTimeStamp(fileAssetLastAudioSampleBuffer!)) {
                            processAudioSampleBuffer(fileAssetLastAudioSampleBuffer!)
                        }
                    }
                    
                    return
                }
            }
        }
    }
    
    private func processAudioSampleBuffer(sampleBuffer: CMSampleBuffer) {
        
        // record
        if recordNeededAppendSample {
            // create assetWriterAudioInput
            createAssetWriteAudioInputIfNeeded(sampleBuffer)
            
            // assetWriterVideoInput has been inited
            if .Unknown != fileAssetVideoInputStatu {
                // init assetWriter
                if nil == fileAssetWriter && !fileAssetWriterInitFail {
                    processRecordStart()
                }
                
                if !fileAssetWriterInitFail && (.Fail == fileAssetVideoInputStatu || fileSegmentHasVideo) {
                    let duration = CMSampleBufferGetDuration(sampleBuffer)
                    appendAudioSampleBuffer(sampleBuffer, withDuration: duration, isFirstBuffer: !fileSegmentHasAudio)
                    return
                }
            }
        }
    }
}


extension AwesomeVisualRecorder {
    
    public func mergeSegments(complete: ((output: String?) -> Void)?) {
        
        if let path = _delegate?.assetWriterMergedFileURL?(self) {
            
            let composition = makeCompositionFromSegments()
            unlink(path.path!)
            
            let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)
            exportSession!.outputURL = path
            exportSession!.outputFileType = AVFileTypeMPEG4
            
            exportSession!.exportAsynchronouslyWithCompletionHandler {
                switch exportSession!.status {
                case AVAssetExportSessionStatus.Completed:
                    dispatch_async(dispatch_get_main_queue()) {
                        complete?(output: path.path)
                    }
                    AwesomeVisualMessage(.Debug, info: "Export complete.")
                    return
                    
                case AVAssetExportSessionStatus.Failed:
                    AwesomeVisualMessage(.Error, info: "Export fail.")
                    break
                case AVAssetExportSessionStatus.Cancelled:
                    AwesomeVisualMessage(.Error, info: "Export canceled.")
                    break
                default:
                    AwesomeVisualMessage(.Error, info: "Export unknown statu.")
                    break
                }
                
                dispatch_async(dispatch_get_main_queue()) {
                    complete?(output: nil)
                }
            }
            
            return
        }
        
        AwesomeVisualMessage(.Warn, info: "No merged file path.")
        dispatch_async(dispatch_get_main_queue()) {
            complete?(output: nil)
        }
    }
    
    private func makeCompositionFromSegments(composition: AVMutableComposition? = nil) -> AVMutableComposition {
        let newComposition = composition ?? AVMutableComposition()
        var videoCompositionTrack: AVMutableCompositionTrack? = nil
        var audioCompositionTrack: AVMutableCompositionTrack? = nil
        var currentTime = newComposition.duration
        
        for segment in assetOutputAssets {
            let videoAssetTracks = segment.tracksWithMediaType(AVMediaTypeVideo)
            let audioAssetTracks = segment.tracksWithMediaType(AVMediaTypeAudio)
            // get the duration of composition
            currentTime = newComposition.duration
            
            var segmentDuration = kCMTimeInvalid
            var videoTime = currentTime
            
            for track in videoAssetTracks {
                // if no video track there, make one, otherwise use the first one
                if nil == videoCompositionTrack {
                    let intrestedTracks = newComposition.tracksWithMediaType(AVMediaTypeVideo)
                    
                    if intrestedTracks.count > 0 {
                        videoCompositionTrack = intrestedTracks[0]
                        
                    } else {
                        videoCompositionTrack = newComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
                        videoCompositionTrack!.preferredTransform = track.preferredTransform
                    }
                }
                
                // append the video track to composition
                videoTime = appendTracks(track, toCompositionTrack: videoCompositionTrack!, fromTime: videoTime, withDuration: segmentDuration)
                // change segment duration
                segmentDuration = videoTime
            }
            
            var audioTime = currentTime
            
            for track in audioAssetTracks {
                // if no audio track there, make one, otherwise use the first one
                if nil == audioCompositionTrack {
                    let intrestedTracks = newComposition.tracksWithMediaType(AVMediaTypeAudio)
                    
                    if intrestedTracks.count > 0 {
                        audioCompositionTrack = intrestedTracks[0]
                    } else {
                        audioCompositionTrack = newComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    }
                }
                
                // append audio track to composition (make the audio asset track duration equal to segment duration)
                audioTime = appendTracks(track, toCompositionTrack: audioCompositionTrack!, fromTime: audioTime, withDuration: segmentDuration)
            }
        }
        
        return newComposition
    }
    
    private func appendTracks(track: AVAssetTrack, toCompositionTrack compositionTrack: AVMutableCompositionTrack, fromTime time: CMTime, withDuration duration: CMTime) -> CMTime {
        // get the track duration
        var range = track.timeRange
        // make the start time of the track
        let startTime = CMTimeAdd(time, range.start)
        
        // if the segment duration is valid and the track duration bigger than that, then make the track duration equal to it
        if CMTIME_IS_VALID(duration) {
            let endTime = CMTimeAdd(startTime, range.duration)
            
            if 0 < CMTimeCompare(endTime, duration) {
                range = CMTimeRangeMake(range.start, CMTimeSubtract(range.duration, CMTimeSubtract(endTime, duration)))
//                AwesomeVisualMessage(.Debug, info: "Track trunced [origin: \(duration) new: \(range.duration)].")
            }
        }
        
        // if the track range is valid, then append it to the composition track
        if 0 < CMTimeCompare(range.duration, kCMTimeZero) {
            do {
                try compositionTrack.insertTimeRange(range, ofTrack: track, atTime: startTime)
            } catch {
                AwesomeVisualMessage(.Error, info: "Merge track fail.")
            }
            
            // finally return the appended segment duration
            return CMTimeAdd(time, range.duration)
        }
        
        return time
    }
}


// MARK: - AwesomeVisualRecorder Delegate

extension AwesomeVisualRecorder {
    public func assetWriterFileURL(recorder: AwesomeVisualRecorder) -> NSURL? {
        let file = "\(NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String)/awesomevisual.mp4"
        unlink(file)
        return NSURL(fileURLWithPath: file)
    }
    
    public func assetWriterMergedFileURL(recorder: AwesomeVisualRecorder) -> NSURL? {
        let file = "\(NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String)/awesomevisual_merged.mp4"
        unlink(file)
        return NSURL(fileURLWithPath: file)
    }
    
    /// settings for video writer
    /// description: sampleBuffer description
    /// videoSize: sampleBuffer frame size
    public func settingsForVideoWriterInput(recorder: AwesomeVisualRecorder, description: CMFormatDescription?, videoSize: CGSize) -> [String : AnyObject]? {
        return [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : (videoSize.width == 0) ? 1280 : videoSize.width,
            AVVideoHeightKey: (videoSize.height == 0) ? 720 : videoSize.height
        ]
    }
    
    public func settingsForVideoWriterInputPixelBufferAdaptor(recorder: AwesomeVisualRecorder, description: CMFormatDescription?) -> [String : AnyObject]? {
        return [:]
    }
    
    public func settingsForAudioWriterInput(recorder: AwesomeVisualRecorder, description: CMFormatDescription?) -> [String : AnyObject]? {
        return [
            AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey : 1,
            AVSampleRateKey : AVAudioSession.sharedInstance().sampleRate
        ]
    }
}

