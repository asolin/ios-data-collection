import ARKit
import UIKit

protocol ViewControllerDelegate: class {
    func updateCameraMode(_ cameraMode: CameraMode)
}

@available(iOS 11.0, *)
class ViewController: UIViewController {
    @IBOutlet weak private var arView: ARSCNView!
    @IBOutlet weak private var timeLabel: UILabel!
    @IBOutlet weak private var toggleButton: UIButton!
    @IBOutlet weak private var settingsButton: UIButton!
    @IBOutlet weak private var aboutButton: UIButton!
    @IBOutlet weak private var filesButton: UIButton!

    private var updateTimer: DispatchSourceTimer!
    private var avCameraPreview: AVCaptureVideoPreviewLayer!

    weak var captureControllerDelegate: CaptureControllerDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        captureControllerDelegate.setARSession(arView.session)
        arView.delegate = self

        // On the UI thread for now.
        captureControllerDelegate.startCamera(getCameraMode())

        // Assume the AVCaptureSession reference remains valid.
        let avCaptureSession = captureControllerDelegate.getAVCaptureSession()
        avCameraPreview = AVCaptureVideoPreviewLayer(session: avCaptureSession)

        // Tap gesture for start/stop.
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.toggleCapture(_:)))
        tap.numberOfTapsRequired = 1
        toggleButton.addGestureRecognizer(tap);

        setUpdateTimer()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let settingsViewController = segue.destination as? SettingsViewController {
            settingsViewController.viewControllerDelegate = self
            settingsViewController.captureControllerDelegate = captureControllerDelegate
        }
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

        arView.clipsToBounds = true
        avCameraPreview.frame = arView.bounds
        // Use resizeAspectFill instead of resizeAspect for both AV and ARKit camera previews.
        avCameraPreview.videoGravity = AVLayerVideoGravity.resizeAspectFill
        arView.layer.addSublayer(avCameraPreview)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @objc private func toggleCapture(_ sender: UITapGestureRecognizer) {
        if captureControllerDelegate.capturing() {
            captureControllerDelegate.stopCapture()
            self.toggleButton.setTitle("Start", for: .normal)
            UIApplication.shared.isIdleTimerDisabled = false
            settingsButton.isEnabled = true
            filesButton.isEnabled = true
            aboutButton.isEnabled = true
        }
        else {
            captureControllerDelegate.startCapture()
            self.toggleButton.setTitle("Stop", for: .normal)
            UIApplication.shared.isIdleTimerDisabled = true
            settingsButton.isEnabled = false
            filesButton.isEnabled = false
            aboutButton.isEnabled = false
        }
    }

    private func setUpdateTimer() {
        updateTimer?.cancel()
        updateTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        updateTimer.schedule(deadline: .now(), repeating: .milliseconds(500), leeway: .milliseconds(10))
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

extension ViewController: ViewControllerDelegate {
    func updateCameraMode(_ cameraMode: CameraMode) {
        // Once AV Camera has been started, the preview stays opaque even when the camera
        // is stopped, so we toggle the layer visibility.
        if cameraMode == CameraMode.AV {
            self.avCameraPreview.isHidden = false
        }
        else {
            self.avCameraPreview.isHidden = true
        }
    }
}

extension ViewController: ARSCNViewDelegate {
}
