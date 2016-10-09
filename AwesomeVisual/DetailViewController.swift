
import UIKit


class DetailViewController: UIViewController {
    unowned let awesomeVisual: AwesomeVisual
    var backButton: UIButton!
 
    init(visual: AwesomeVisual) {
        awesomeVisual = visual
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor(red: 0.9239, green: 0.9399, blue: 0.7583, alpha: 1.0)
        backButton = UIButton(frame: CGRectMake(20, 40, 45, 35))
        backButton.backgroundColor = UIColor(red: 0.5278, green: 0.4812, blue: 0.8955, alpha: 1.0)
        backButton.setTitle("Back", forState: .Normal)
        backButton.setTitleColor(UIColor.blackColor(), forState: .Normal)
        backButton.titleLabel?.font = UIFont(name: "Arial", size: 13)
        backButton.layer.cornerRadius = 5
        backButton.addTarget(self, action: #selector(backTapped), forControlEvents: .TouchUpInside)
        self.view.addSubview(backButton)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if awesomeVisual.segmentRecoder.outputAssetCount < 1 {
            let ac = UIAlertController(title: "Empty", message: "没有录制的视频", preferredStyle: .Alert)
            let action = UIAlertAction(title: "确定", style: .Default) {
                _ in
                self.backTapped()
            }
            
            ac.addAction(action)
            self.presentViewController(ac, animated: true, completion: nil)
            return
        }
        
        loadSegment()
    }
}

extension DetailViewController: UITableViewDelegate, UITableViewDataSource {
    func backTapped() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func loadSegment() {
        let startY = backButton.frame.origin.y + backButton.frame.size.height
        let table = UITableView(frame: CGRectMake(0, startY, self.view.bounds.width, self.view.bounds.height - startY))
        table.delegate = self
        table.dataSource = self
        table.separatorStyle = .SingleLine
        table.registerClass(UITableViewCell.self, forCellReuseIdentifier: "detailCell")
        self.view.addSubview(table)
    }
}

extension DetailViewController {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return awesomeVisual.segmentRecoder.outputAssetCount
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("detailCell")!
        return cell
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        cell.textLabel?.text = awesomeVisual.segmentRecoder[indexPath.row]?.URL.absoluteString
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let showView = ShowViewController()
        showView.url = awesomeVisual.segmentRecoder[indexPath.row]?.URL
        self.presentViewController(showView, animated: true, completion: nil)
    }
}
