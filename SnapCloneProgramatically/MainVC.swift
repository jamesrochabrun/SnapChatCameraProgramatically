//
//  ViewController.swift
//  SnapCloneProgramatically
//
//  Created by James Rochabrun on 5/5/17.
//  Copyright © 2017 James Rochabrun. All rights reserved.
//

import UIKit

class MainVC: UIViewController {
    
    let menuScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.isPagingEnabled = true
        return sv
    }()
    
    lazy var feedVC: FeedVC = {
        let fVC = FeedVC()
        fVC.view.backgroundColor = .yellow
        return fVC
    }()
    
    lazy var cameraVC : CameraVC = {
        let cVC = CameraVC()
        cVC.view.backgroundColor = .red
        var frame = cVC.view.frame
        frame.origin.x = self.view.frame.width
        cVC.view.frame = frame
        return cVC
    }()
    
    lazy var postVC: PostsVC = {
        let pVC = PostsVC()
        pVC.view.backgroundColor = .green
        var frame = pVC.view.frame
        frame.origin.x = self.view.frame.width * 2
        pVC.view.frame = frame
        return pVC
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(menuScrollView)
        addViewControllerToMenu(feedVC)
        self.addViewControllerToMenu(cameraVC)
        self.addViewControllerToMenu(postVC)
    }
    
    override func viewWillLayoutSubviews() {
         super.viewWillLayoutSubviews()
        NSLayoutConstraint.activate([
            menuScrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
            menuScrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
            menuScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            menuScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        menuScrollView.contentSize = CGSize(width: self.view.frame.width * 3,
                                            height: self.view.frame.size.height)
    }
    
    private func addViewControllerToMenu(_ viewController: UIViewController) {
        
        self.addChildViewController(viewController)
        self.menuScrollView.addSubview(viewController.view)
        viewController.didMove(toParentViewController: self)
    }
}








