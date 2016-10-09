
import UIKit
import AVFoundation


class TinyPlayer: NSObject {
    private var _isPlaying = false
    private var _player: AVPlayer
    private var _playerLayer: AVPlayerLayer
    private var _playerItem: AVPlayerItem?
    
    var hiddenWhenPause = true
    var cyclePlay = true
    var autoPlay = true
    
    var url: NSURL? {
        
        didSet {
            if nil == url {
                if nil != oldValue {
//                    pause()
                    _player.replaceCurrentItemWithPlayerItem(nil)
                    removeObservers()
                    _playerItem = nil
                }
                
                return
            }
            
            if nil != oldValue && url == oldValue {
                if autoPlay {
                    play()
                }
                return
            }
            
//            pause()
            removeObservers()
            _playerItem = AVPlayerItem(URL: url!)
            addObservers()
            _player.replaceCurrentItemWithPlayerItem(_playerItem!)
        }
    }
    
    var playLayer: AVPlayerLayer {
        get {
            return _playerLayer
        }
    }
    
    private func addObservers() {
        if nil != _playerItem {
            _playerItem!.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.New, context: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(playDidEnd), name: AVPlayerItemDidPlayToEndTimeNotification, object: _playerItem!)
        }
    }
    
    private func removeObservers() {
        if nil != _playerItem {
            _playerItem!.removeObserver(self, forKeyPath: "status")
            NSNotificationCenter.defaultCenter().removeObserver(self)
        }
    }
    
    override init() {
        _player = AVPlayer()
        _playerLayer = AVPlayerLayer(player: _player)
        super.init()
        
        if hiddenWhenPause {
            _playerLayer.hidden = true
        }
    }
    
    deinit {
        removeObservers()
    }
    
    convenience init(playURL: NSURL) {
        self.init()
        url = playURL
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        if keyPath == "status" {
            let item = object as! AVPlayerItem
            if item.status == AVPlayerItemStatus.ReadyToPlay {
                if autoPlay {
                    play()
                }
            }
        }
    }
    
    func changePlayingStat() {
        if play() {
            pause()
        }
    }
    
    private func forcePlay() {
        _player.rate = 1.0
        _isPlaying = true
    }
    
    func play() -> Bool {
        guard _playerItem != nil && _playerItem!.status == AVPlayerItemStatus.ReadyToPlay else {
            return _isPlaying
        }
        
        if !_isPlaying {
            
            if hiddenWhenPause {
                _playerLayer.hidden = false
            }
            
            forcePlay()
            return false
            
        } else {
            return _isPlaying
        }
    }
    
    private func forcePause() {
        _player.rate = 0
        _isPlaying = false
    }
    
    func pause() -> Bool {
        guard _playerItem != nil && _playerItem!.status == AVPlayerItemStatus.ReadyToPlay else {
            return _isPlaying
        }
        
        if _isPlaying {
            
            if hiddenWhenPause {
                _playerLayer.hidden = true
            }
            
            forcePause()
            return true
            
        } else {
            return _isPlaying
        }
    }
    
    func playDidEnd() {
        pause()
        _player.seekToTime(CMTimeMake(0, 1))
        
        if cyclePlay {
            play()
        }
    }
    
    func addToView(toView: UIView, fillFrame frame: CGRect, atIndex index: UInt32, videoGravity gravity: String = AVLayerVideoGravityResizeAspect) {
//        removeFromView(toView)
        if _playerLayer.superlayer == toView.layer {
            return
        }
        _playerLayer.frame = frame
        _playerLayer.backgroundColor = UIColor.blackColor().CGColor
        _playerLayer.videoGravity = gravity
        toView.layer.insertSublayer(_playerLayer, atIndex: index)
    }
    
    func removeFromView(fromView: UIView?) {
        if nil != fromView {
            if _playerLayer.superlayer != fromView!.layer {
                return
            }
        }
//        if nil != fromView.layer.sublayers {
//            for item in fromView.layer.sublayers! {
//                if item is AVPlayerLayer {
//                    item.removeFromSuperlayer()
//                    ZMDebugInfo(.Info, debugInfo: "Remove exist layer")
//                }
//            }
//        }
        
        _playerLayer.removeFromSuperlayer()
    }
    
}
