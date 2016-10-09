//
// AwesomeVisual+GPUImage.swift
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


class GPUImageCameraForAwesomeVisual: GPUImageVideoCamera {
    weak var awesomeVisual: AwesomeVisual?
    
    convenience init(visual: AwesomeVisual, sessionPreset: String!, cameraPosition: AVCaptureDevicePosition) {
        self.init(sessionPreset: sessionPreset, cameraPosition: cameraPosition)
        awesomeVisual = visual
    }
    
    override func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        guard let visual = awesomeVisual else {
            return
        }
        
        if sessionVideoOutput == captureOutput {
            super.captureOutput(captureOutput, didOutputSampleBuffer: sampleBuffer, fromConnection: connection)
            
        } else {
            visual.captureOutput(captureOutput, didOutputSampleBuffer: sampleBuffer, fromConnection: connection)
        }
    }    
}


public class GPUImageRawOutputForAwesomeVisual: GPUImageRawDataOutput {
    weak var awesomeVisual: AwesomeVisual?
    
    convenience init(visual: AwesomeVisual, imageSize newImageSize: CGSize, resultsInBGRAFormat: Bool) {
        self.init(imageSize: newImageSize, resultsInBGRAFormat: resultsInBGRAFormat)
        awesomeVisual = visual
    }
    
    override public func newFrameReadyAtTime(frameTime: CMTime, atIndex textureIndex: Int) {
        guard let visual = awesomeVisual else {
            return
        }
        
        super.newFrameReadyAtTime(frameTime, atIndex: textureIndex)

        var pixelBuffer: CVPixelBuffer?
        var videoInfo: CMVideoFormatDescription?
        var sampleBuffer: CMSampleBuffer?
        
        let outputSize = maximumOutputSize()
        let sourceBytes = rawBytesForImage
        let bytesPerRow = bytesPerRowInOutput()
        lockFramebufferForReading()
        
        /* var result: OSStatus = */CVPixelBufferCreateWithBytes(kCFAllocatorDefault, Int(outputSize.width), Int(outputSize.height), kCVPixelFormatType_32BGRA, sourceBytes, Int(bytesPerRow), nil, nil, nil, &pixelBuffer)
        
        if nil == pixelBuffer {
            unlockFramebufferAfterReading()
            return
        }
        
        /*result = */CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer!, &videoInfo)
        
        if nil == videoInfo {
            unlockFramebufferAfterReading()
            return
        }
        
        var timingInfo = CMSampleTimingInfo(duration: kCMTimeInvalid, presentationTimeStamp: frameTime, decodeTimeStamp: kCMTimeInvalid)
        
        /*result = */CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer!, true, nil, nil, videoInfo!, &timingInfo, &sampleBuffer)
        
        if nil == sampleBuffer {
            unlockFramebufferAfterReading()
            return
        }
        
        unlockFramebufferAfterReading()
        visual.segmentRecoder.captureRecordProcess(visual.targetVideoOutput!, didOutputSampleBuffer: sampleBuffer!)

    }
}


// MARK: - GPUImage Part

extension AwesomeVisual {
    
    private func initGPUImageInput() -> Bool {
        if nil == gpuImageVideoCamera {
            gpuImageVideoCamera = GPUImageCameraForAwesomeVisual(visual: self, sessionPreset: AVCaptureSessionPresetHigh, cameraPosition: videoInputDevice!.position)
            switch videoOrientation {
            case .Portrait:
                gpuImageVideoCamera!.outputImageOrientation = .Portrait
            case .PortraitUpsideDown:
                gpuImageVideoCamera!.outputImageOrientation = .PortraitUpsideDown
            case .LandscapeLeft:
                gpuImageVideoCamera!.outputImageOrientation = .LandscapeLeft
            case .LandscapeRight:
                gpuImageVideoCamera!.outputImageOrientation = .LandscapeRight
            }
            gpuImageVideoCamera!.horizontallyMirrorRearFacingCamera = false
            gpuImageVideoCamera!.horizontallyMirrorFrontFacingCamera = false
            gpuImageVideoCamera!.addAudioInputsAndOutputs()
            targetSession = gpuImageVideoCamera!.captureSession
            targetVideoInput = gpuImageVideoCamera!.sessionVideoInput
            targetVideoOutput = gpuImageVideoCamera!.sessionVideoOutput
            targetAudioInput = gpuImageVideoCamera!.sessionAudioInput
            targetAudioOutput = gpuImageVideoCamera!.sessionAudioOutput
            gpuImageOutputEndPoint = gpuImageVideoCamera
            
            AwesomeVisualMessage(.Info, info: "GPUImage input initialized.")
            return true
        }
        
        AwesomeVisualMessage(.Warn, info: "GPUImage input initialization fail.")
        return false
    }
    
    private func deinitGPUImageInput() {
        if nil != gpuImageVideoCamera {
            gpuImageVideoCamera!.removeInputsAndOutputs()
            gpuImageVideoCamera!.removeAllTargets()
            gpuImageVideoCamera = nil
            AwesomeVisualMessage(.Info, info: "GPUImage input deinitialized.")
        }
    }
    
    func initGPUImageView(frame: CGRect) {
        guard nil != gpuImageOutputEndPoint else {
            return
        }
        
        if nil == gpuImageDataOutput {
            gpuImageDataOutput = GPUImageRawOutputForAwesomeVisual(visual: self, imageSize: frame.size, resultsInBGRAFormat: true)
            gpuImageOutputEndPoint!.addTarget(gpuImageDataOutput!)
        }
        
        if nil == gpuImageView {
            gpuImageView = GPUImageView(frame: frame)
            gpuImageOutputEndPoint!.addTarget(gpuImageView!)
            
            switch videoGravity {
            case AVLayerVideoGravityResizeAspect:
                gpuImageView!.fillMode = .PreserveAspectRatio
            case AVLayerVideoGravityResizeAspectFill:
                gpuImageView!.fillMode = .PreserveAspectRatioAndFill
            default:
                gpuImageView!.fillMode = .Stretch
            }
            
            AwesomeVisualMessage(.Info, info: "GPUImage view initialized.")
            return
            
        }
        
        gpuImageView!.frame = frame
    }
    
    func deinitGPUImageView() {
        if nil != gpuImageDataOutput {
            if nil != gpuImageOutputEndPoint {
                gpuImageOutputEndPoint!.removeTarget(gpuImageDataOutput!)
            }
            gpuImageDataOutput = nil
        }
        
        if nil != gpuImageView {
            if nil != gpuImageOutputEndPoint {
                gpuImageOutputEndPoint!.removeTarget(gpuImageView!)
            }
            
            gpuImageView!.removeFromSuperview()
            gpuImageView = nil
            AwesomeVisualMessage(.Info, info: "GPUImage view deinitialized.")
        }
    }
    
    func prepareGPUImage(complete: ((AwesomeVisual) -> Void)?) -> Bool {
        
        if !initGPUImageInput() {
            unprepareGPUImage()
            mediaStat = .Error
            
        } else {
            switchFilter(nil, vertextShader: nil)
            mediaStat = .Success
        }

        
        AwesomeVisualMessage(.Info, info: "Media session configure success.")
        complete?(self)
        return true
    }
    
    func unprepareGPUImage() {
        runSynchronouslyOnVideoProcessingQueue {
            self.stopCapture(nil)
            self.deinitGPUImageView()
            self.deinitGPUImageInput()
            AwesomeVisualMessage(.Info, info: "Media session deinitialized.")
        }
    }
}


// MARK: - Public 

extension AwesomeVisual {
    
    public func switchFilterFile(fragmentShaderFile: String?, fragmentShaderFileType: String?, vertextShaderFile: String?, vertextShaderFileType: String?) -> Bool {
        var fragment: String?
        var vertext: String?
        
        if fragmentShaderFile != nil {
            if let path = NSBundle.mainBundle().pathForResource(fragmentShaderFile!, ofType: fragmentShaderFileType) {
                do {
                    fragment = try String.init(contentsOfURL: NSURL(fileURLWithPath:  path))
                    
                } catch {
                    return false
                }
                
                if nil != vertextShaderFile {
                    if let path = NSBundle.mainBundle().pathForResource(vertextShaderFile!, ofType: vertextShaderFileType) {
                        do {
                            vertext = try String.init(contentsOfURL: NSURL(fileURLWithPath:  path))
                            
                        } catch {}
                    }
                }
            }
        }
        
        return switchFilter(fragment, vertextShader: vertext)
    }
    
    public func switchFilter(fragmentShader: String?, vertextShader: String?) -> Bool {
        guard type == .GPUImage else {
            AwesomeVisualMessage(.Warn, info: "GPUImage is not supported.")
            return false
        }
        
        guard !segmentRecoder.isRecording else {
            AwesomeVisualMessage(.Warn, info: "GPUImage is recording so that filter can not be applied.")
            return false
        }
        
        guard let endPoint = gpuImageOutputEndPoint else {
            AwesomeVisualMessage(.Error, info: "GPUImage filter switch fail.")
            return false
        }
        
        var newFilter: GPUImageFilter?
        
        if nil != fragmentShader && nil != vertextShader {
            newFilter = GPUImageFilter(vertexShaderFromString: fragmentShader!, fragmentShaderFromString: vertextShader!)
        } else {
            if nil != fragmentShader {
                newFilter = GPUImageFilter(fragmentShaderFromString: fragmentShader!)
            }
        }
        
        gpuImageOutputEndPoint = newFilter ?? gpuImageVideoCamera!
        
        if endPoint != gpuImageOutputEndPoint {
            let targets = endPoint.targets()
            endPoint.removeAllTargets()
            gpuImageVideoCamera!.removeAllTargets()
            
            for target in targets {
                if let t = target as? GPUImageInput {
                    gpuImageOutputEndPoint!.addTarget(t)
                }
            }
            
            if gpuImageOutputEndPoint == newFilter {
                gpuImageVideoCamera!.addTarget(newFilter!)
            }
        }
        
        AwesomeVisualMessage(.Debug, info: "GPUImage filter switched.")
        return true
    }
    
    public func removeVideoAtIndex(index: Int) {
        segmentRecoder.removeRecordAssetAtIndex(index)
    }
    
    public func removeAllVideo() {
        segmentRecoder.removeAllRecordAsset()
    }
}
