//
//  ViewController.swift
//  AudioPlayer
//
//  Created by Anthony Smaldore on 10/30/24.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var recordStartedButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func recordStarted(sender: UIButton) {
        recordStartedButton.setTitle("Recording...", for: .normal)
        // Wait for 2 seconds, then update the button title back to "Start Recording"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.recordStartedButton.setTitle("Start Recording", for: .normal)
        }
        
    }
    
    @IBOutlet weak var recordingStoppedButton: UIButton!
    
    @IBAction func recordStopped(sender: UIButton) {
        recordingStoppedButton.setTitle("Recording stopping...", for: .normal)
        // Wait for 2 seconds, then update the button title back to "Stop Recording"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.recordingStoppedButton.setTitle("Stop Recording", for: .normal)
        }
    }


}

