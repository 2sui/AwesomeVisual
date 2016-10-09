
import UIKit
import GPUImage

class ViewController: UIViewController, AwesomeVisualDelegate, AwesomeVisualRecorderDelegate {
    @IBOutlet weak var cameraSwitchButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var makeButton: UIButton!
    @IBOutlet weak var loadButton: UIButton!
    @IBOutlet weak var detailShowButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    
    var media: AwesomeVisual?
    var focusView: UIImageView?
    func getFragment() -> String? {
        return "Shader5"
    }
    func getVertex() -> String? {
        return nil
    }
    
    var fragment: String?
    var vertex: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.view.backgroundColor = UIColor.blackColor()
        cameraSwitchButton.addTarget(self, action: #selector(cameraSwitchTapped), forControlEvents: .TouchUpInside)
        detailShowButton.addTarget(self, action: #selector(detailShowTapped), forControlEvents: .TouchUpInside)
        flashButton.addTarget(self, action: #selector(flashTapped), forControlEvents: .TouchUpInside)
        filterButton.addTarget(self, action: #selector(filterTapped), forControlEvents: .TouchUpInside)
        recordButton.addTarget(self, action: #selector(recordTouchDown), forControlEvents: .TouchDown)
        recordButton.addTarget(self, action: #selector(recordTouchUp), forControlEvents: .TouchUpInside)
        clearButton.addTarget(self, action: #selector(cleanAsset), forControlEvents: .TouchUpInside)
        loadButton.addTarget(self, action: #selector(loadCamera), forControlEvents: .TouchUpInside)
        makeButton.addTarget(self, action: #selector(makeTapped), forControlEvents: .TouchUpInside)
        
        
        detailShowButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        detailShowButton.layer.cornerRadius = 24
        detailShowButton.layer.masksToBounds = true
        loadButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        loadButton.layer.cornerRadius = 24
        loadButton.layer.masksToBounds = true
        makeButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        makeButton.layer.cornerRadius = 24
        makeButton.layer.masksToBounds = true
        clearButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        clearButton.layer.cornerRadius = 24
        makeButton.layer.masksToBounds = true
        
        flashButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        filterButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //
        
    }
    
    func loadCamera() {
        if nil == media {
            loadButton.enabled = false
            media = AwesomeVisual()
            media!.delegate = self
            media!.segmentRecoder.delegate = self
            
            let complete: (AwesomeVisual) -> Void = {
                [unowned self] visual in
                switch visual.visualStat {
                case .Success:
                    visual.startCapture {
                        startVisual in
                        if let preview = startVisual.preparePreviewLayer(self.view.bounds) {
                            let gesture = UITapGestureRecognizer(target: self, action: #selector(self.focusAndExposeTap))
                            preview.userInteractionEnabled = true
                            preview.addGestureRecognizer(gesture)
                            
                            self.focusView = UIImageView(frame: CGRectMake(0, 0, 50, 50))
                            self.focusView!.hidden = true
                            if let path = NSBundle.mainBundle().pathForResource("record_focus@2x", ofType: "png") {
                                let image = UIImage(contentsOfFile: path)
                                self.focusView!.image = image
                            }
                            preview.addSubview(self.focusView!)
                            self.view.insertSubview(preview, atIndex: 0)
                        }
                    }
                    
                case .NotAuthorized:
                    self.media = nil
                    
                    let alert = UIAlertController(title: "错误", message: "请在设置中添加相机权限", preferredStyle: .Alert)
                    let action = UIAlertAction(title: "确定", style: .Default, handler: nil)
                    alert.addAction(action)
                    self.presentViewController(alert, animated: true, completion: nil)
                    
                default:
                    self.media = nil
                    
                    let alert = UIAlertController(title: "错误", message: "AwesomeVisual 初始化失败", preferredStyle: .Alert)
                    let action = UIAlertAction(title: "确定", style: .Default, handler: nil)
                    alert.addAction(action)
                    self.presentViewController(alert, animated: true, completion: nil)
                }
                
                
                self.loadButton.enabled = true
                
            }
            
            media!.prepareVisual(complete)
            
        } else {
            loadButton.enabled = false
            media = nil
            loadButton.enabled = true
        }
    }

}

extension ViewController {
    
    func makeTapped() {
        
        if nil == media {
            let ac = UIAlertController(title: "Oooooooooops", message: "camera 没有创建", preferredStyle: .Alert)
            let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
            ac.addAction(action)
            self.presentViewController(ac, animated: true, completion: nil)
            return
        }
        
        if media!.segmentRecoder.outputAssetCount < 1 {
            let ac = UIAlertController(title: "Empty", message: "没有视频片段", preferredStyle: .Alert)
            let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
            ac.addAction(action)
            self.presentViewController(ac, animated: true, completion: nil)
            return
        }
        
        let indiLayer = UIView(frame: CGRectMake((self.view.bounds.width - 50)/2, (self.view.bounds.height - 50)/2, 50, 50))
        let indicator = UIActivityIndicatorView(frame: CGRectMake(5,5,40,40))
        indiLayer.addSubview(indicator)
        self.view.addSubview(indiLayer)
        indiLayer.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        
        indicator.startAnimating()
        media?.makeupVideo {
            path in
            let strongSelf = self
            dispatch_async(dispatch_get_main_queue()) {
                indicator.stopAnimating()
                indicator.removeFromSuperview()
                indiLayer.removeFromSuperview()
                
                if let output = path {
                    let show = ShowViewController()
                    show.url = NSURL(fileURLWithPath: output)
                    strongSelf.presentViewController(show, animated: true, completion: nil)
                    return
                }
                
                let ac = UIAlertController(title: "Fail", message: "视频合并失败", preferredStyle: .Alert)
                let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
                ac.addAction(action)
                self.presentViewController(ac, animated: true, completion: nil)
            }
        }
    }
    
    func cameraSwitchTapped() {
        if media?.cameraPosition == .Front {
            media?.cameraPosition = .Back
            flashButton.hidden = false
            
        } else {
            media?.flashMode = .Off
            flashButton.hidden = true
            
            if let icon = NSBundle.mainBundle().pathForResource("record_ico_flashlight@2x", ofType: "png") {
                let image = UIImage(contentsOfFile: icon)
                flashButton.setImage(image, forState: .Normal)
            }
            
            media?.cameraPosition = .Front
        }
    }
    
    func detailShowTapped() {
        if nil != media {
            let detail = DetailViewController(visual: media!)
            detail.view.backgroundColor = UIColor.orangeColor()
            self.presentViewController(detail, animated: true, completion: nil)
            return
        }
        
        let ac = UIAlertController(title: "提示", message: "camera 没有创建", preferredStyle: .Alert)
        let action = UIAlertAction(title: "确定", style: .Default, handler: nil)
        ac.addAction(action)
        self.presentViewController(ac, animated: true, completion: nil)
    }
    
    func flashTapped() {
        var icon: String?
        if media?.flashMode == .On {
            media?.flashMode = .Off
            icon = NSBundle.mainBundle().pathForResource("record_ico_flashlight@2x", ofType: "png")
            
        } else {
            media?.flashMode = .On
            icon = NSBundle.mainBundle().pathForResource("record_ico_flashlight_1@2x", ofType: "png")
        }
        
        if nil != icon {
            let image = UIImage(contentsOfFile: icon!)
            flashButton.setImage(image, forState: .Normal)
        }
    }
    
    func filterTapped() {
        var icon: String?
        if nil != fragment {
            media?.switchFilter(nil, vertextShader: nil)
            fragment = nil
            vertex = nil
            icon = NSBundle.mainBundle().pathForResource("record_ico_mackup@2x", ofType: "png")
            
        } else {
            fragment = getFragment()
            vertex = getVertex()
            media?.switchFilterFile(fragment, fragmentShaderFileType: "fsh", vertextShaderFile: vertex, vertextShaderFileType: "vsh")
            icon = NSBundle.mainBundle().pathForResource("record_ico_mackup_1@2x", ofType: "png")
        }
        
        if nil != icon {
            let image = UIImage(contentsOfFile: icon!)
            filterButton.setImage(image, forState: .Normal)
        }
    }
    
    func recordTouchDown() {
        guard nil != media else {
            return
        }
//        if !media!.segmentRecoder.isProcessing {
//            media!.startRecord()
//            
//        } else {
//            media!.resumeRecord()
//        }
        if !media!.segmentRecoder.isProcessing {
            media!.startRecord()
        }
    }
    
    func recordTouchUp() {
        guard nil != media else {
            return
        }
//        if media!.segmentRecoder.isRecording {
//            media!.pauseRecord()
//        }
        if media!.segmentRecoder.isProcessing {
            media!.stopRecord()
        }
    }
    
    func focusAndExposeTap(gesture: UIGestureRecognizer) {
        media?.focusAndExposeTap(gesture)
        
        if let focus = focusView {
            let loc = gesture.locationInView(gesture.view)
            focus.center = loc
            focus.hidden = false
            UIView.animateWithDuration(0.2, animations: {
                focus.transform = CGAffineTransformMakeScale(1.2, 1.2)
                
                }, completion: {
                    _ in
                    UIView.animateWithDuration(0.5, animations: {
                        focus.transform = CGAffineTransformIdentity
                        }, completion: {
                            _ in
                            focus.hidden = true
                    })
            })
        }
    }
    
    func cleanAsset() {
        media?.removeAllVideo()
    }
}

extension ViewController {
    func shouldEneableAssetWriter(awesomeVisual: AwesomeVisual) -> Bool {
        return true
    }
    
    func shouldEnableMergeAssetWriter(awesomeVisual: AwesomeVisual) -> Bool {
        return true
    }
    
    func assetWriterMergedFileURL(recorder: AwesomeVisualRecorder) -> NSURL? {
        let path = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String)
        let file = "\(path)/awesomevisualFinal.mp4"
        
        if NSFileManager.defaultManager().fileExistsAtPath(file) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(file)
            } catch {}
        }
        
        return NSURL(fileURLWithPath: file)
    }
    
    func assetWriterFileURL(recorder: AwesomeVisualRecorder) -> NSURL? {
        let docPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        let file = "\(docPath)/awesomevisual_tmp_\(media?.segmentRecoder.outputAssetCount ?? 0).mp4"
        let manager = NSFileManager.defaultManager()
        
        if manager.fileExistsAtPath(file) {
            do {
                try manager.removeItemAtPath(file)
                
            } catch _ {
            }
        }
        
        return NSURL(fileURLWithPath: file)
    }
    
    /// settings for video writer
    /// description: sampleBuffer description
    /// videoSize: sampleBuffer frame size
    func settingsForVideoWriterInput(recorder: AwesomeVisualRecorder, description: CMFormatDescription?, videoSize: CGSize) -> [String : AnyObject]? {
        return [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : (videoSize.width == 0) ? 1280 : videoSize.width,
            AVVideoHeightKey: (videoSize.height == 0) ? 720 : videoSize.height
        ]
    }
    
    func settingsForVideoWriterInputPixelBufferAdaptor(recorder: AwesomeVisualRecorder, description: CMFormatDescription?) -> [String : AnyObject]? {
        return [:]
    }
    
    func settingsForAudioWriterInput(recorder: AwesomeVisualRecorder, description: CMFormatDescription?) -> [String : AnyObject]? {
        return [
            AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey : 1,
            AVSampleRateKey : AVAudioSession.sharedInstance().sampleRate
        ]
    }
    
    // life cycle
    func willBeginRecord(recorder: AwesomeVisualRecorder) {
        AwesomeVisualMessage(.Info, info: "view controller WillBeginRecord.")
    }
     
    func didBeginRecord(recorder: AwesomeVisualRecorder) {
        AwesomeVisualMessage(.Info, info: "view controller DidBeginRecord.")
    }
     
    func willEndRecord(recorder: AwesomeVisualRecorder) {
        AwesomeVisualMessage(.Info, info: "view controller WillEndRecord.")
    }
     
    func didEndRecord(recorder: AwesomeVisualRecorder) {
        AwesomeVisualMessage(.Info, info: "view controller DidEndRecord.")
    }
    
    func whenStart(recorder: AwesomeVisualRecorder) {
        NSLog("\(#function)")
        if let icon = NSBundle.mainBundle().pathForResource("record_ico_rec@2x", ofType: "png") {
            let image = UIImage(contentsOfFile: icon)
            self.recordButton.setImage(image, forState: .Normal)
        }
    }
    
    func whenPause(recorder: AwesomeVisualRecorder) {
        NSLog("\(#function)")
        if let icon = NSBundle.mainBundle().pathForResource("record_button@2x", ofType: "png") {
            let image = UIImage(contentsOfFile: icon)
            self.recordButton.setImage(image, forState: .Normal)
        }
    }
    
    func whenResume(recorder: AwesomeVisualRecorder) {
        NSLog("\(#function)")
        if let icon = NSBundle.mainBundle().pathForResource("record_ico_rec@2x", ofType: "png") {
            let image = UIImage(contentsOfFile: icon)
            self.recordButton.setImage(image, forState: .Normal)
        }
    }
    
    func whenStop(recorder: AwesomeVisualRecorder) {
        NSLog("\(#function)")
        if let icon = NSBundle.mainBundle().pathForResource("record_button@2x", ofType: "png") {
            let image = UIImage(contentsOfFile: icon)
            self.recordButton.setImage(image, forState: .Normal)
        }
    }
 
}

