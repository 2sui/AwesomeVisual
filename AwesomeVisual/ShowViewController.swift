
import UIKit


class ShowViewController: UIViewController {
    let backButton = UIButton()
    var player: TinyPlayer?
    var url: NSURL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.blackColor()
        backButton.frame = CGRectMake(20, 20, 48, 35)
        backButton.setTitle("Back", forState: .Normal)
        backButton.setTitleColor(UIColor.blackColor(), forState: .Normal)
        backButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        backButton.layer.cornerRadius = 5
        backButton.layer.masksToBounds = true
        backButton.addTarget(self, action: #selector(backTapped), forControlEvents: .TouchUpInside)
        self.view.addSubview(backButton)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if nil == player {
            player = TinyPlayer()
            player?.cyclePlay = false
            player?.addToView(self.view, fillFrame: self.view.bounds, atIndex: 0)
            player?.url = url
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if nil != player {
            player?.removeFromView(nil)
            player = nil
        }
    }
}

extension ShowViewController {
    func backTapped() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
