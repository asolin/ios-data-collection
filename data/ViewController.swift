//
//  ViewController.swift
//  data
//
//  Created by Arno Solin on 23.9.2017.
//  Copyright © 2017 Arno Solin. All rights reserved.
//

import ARKit
import UIKit

@available(iOS 11.0, *)
class ViewController: UIViewController {
    /* Outlets */
    @IBOutlet weak private var toggleButton: UIButton!
    @IBOutlet weak private var arView: ARSCNView!
    @IBOutlet weak private var timeLabel: UILabel!

    private var updateTimer: DispatchSourceTimer!

    var captureControllerDelegate: CaptureControllerDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        arView.delegate = self
        captureControllerDelegate.setARSession(arView.session)

        // Tap gesture for start/stop.
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.toggleCapture(_:)))
        tap.numberOfTapsRequired = 1
        toggleButton.addGestureRecognizer(tap);

        setUpdateTimer()
    }

    override func viewWillAppear(_ animated: Bool) {
        timeLabel.text = ""
    }

    override func viewDidLayoutSubviews() {
        toggleButton.layer.borderWidth = 2

        if captureControllerDelegate.capturing() {
            animateButtonRadius(toValue: toggleButton.frame.height/4.0)
            toggleButton.layer.masksToBounds = true

            toggleButton.layer.borderColor = UIColor.green.cgColor
            toggleButton.layer.backgroundColor = UIColor.white.cgColor
            toggleButton.layer.shadowColor = UIColor.white.cgColor
        }
        else {
            animateButtonRadius(toValue: toggleButton.frame.height/2.0)
            toggleButton.layer.masksToBounds = true

            toggleButton.layer.borderColor = UIColor.red.cgColor
            toggleButton.layer.backgroundColor = UIColor.white.cgColor
            toggleButton.layer.shadowColor = UIColor.white.cgColor
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @objc private func toggleCapture(_ sender: UITapGestureRecognizer) {
        if (!captureControllerDelegate.capturing()) {
            captureControllerDelegate.startCapture();
            self.toggleButton.setTitle("Stop", for: .normal);
            //animateButtonRadius(toValue: toggleButton.frame.height/10.0)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        else {
            captureControllerDelegate.stopCapture();
            self.toggleButton.setTitle("Start", for: .normal)
            //animateButtonRadius(toValue: toggleButton.frame.height/2.0)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func setUpdateTimer() {
        updateTimer?.cancel()
        updateTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        updateTimer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(10))
        updateTimer.setEventHandler { [weak self] in
            if let recTime = self?.captureControllerDelegate.getRecTime() {
                self?.timeLabel.text = String(format: "Rec time: %.02f s", recTime)
            }
            else {
                self?.timeLabel.text = ""
            }
        }
        updateTimer.resume()
    }

    // MARK: - Unwind action for the extra view
    @IBAction func unwindToMain(segue: UIStoryboardSegue) {
    }

    // MARK: - Animate button
    func animateButtonRadius(toValue: CGFloat) {
        let animation = CABasicAnimation(keyPath:"cornerRadius")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.fromValue = toggleButton.layer.cornerRadius
        animation.toValue = toValue
        animation.duration = 0.5
        toggleButton.layer.add(animation, forKey: "cornerRadius")
        toggleButton.layer.cornerRadius = toValue
    }
}

extension ViewController: ARSCNViewDelegate {
}
