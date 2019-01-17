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
    var captureSessionQueue: DispatchQueue!

    override func viewDidLoad() {
        super.viewDidLoad()

        captureControllerDelegate.setARSession(arView.session)
        arView.delegate = self

        captureSessionQueue.async {
            self.captureControllerDelegate.startCamera(getCameraMode())
        }

        // Assume the AVCaptureSession reference is valid before startCamera() completes and
        // remains valid for the duration of the program run.
        let avCaptureSession = captureControllerDelegate.getAVCaptureSession()
        avCameraPreview = AVCaptureVideoPreviewLayer(session: avCaptureSession)
        arView.clipsToBounds = true
        avCameraPreview.frame = arView.bounds
        // Use resizeAspectFill instead of resizeAspect for both AV and ARKit camera previews.
        avCameraPreview.videoGravity = AVLayerVideoGravity.resizeAspectFill
        arView.layer.addSublayer(avCameraPreview)

        // Put a shadow under record time label.
        timeLabel.text = ""
        timeLabel.layer.shadowOffset = CGSize.zero
        timeLabel.layer.masksToBounds = false
        timeLabel.layer.shadowColor = UIColor.white.cgColor
        timeLabel.layer.shadowRadius = 1.0
        timeLabel.layer.shadowOpacity = 1.0
        timeLabel.layer.shouldRasterize = true

        toggleButton.layer.backgroundColor = UIColor.white.cgColor
        toggleButton.layer.shadowColor = UIColor.white.cgColor
        toggleButton.layer.masksToBounds = true
        toggleButton.layer.borderWidth = 2

        setupButtons(CaptureStatus.paused)

        setUpdateTimer()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let settingsViewController = segue.destination as? SettingsViewController {
            settingsViewController.viewControllerDelegate = self
            settingsViewController.captureControllerDelegate = captureControllerDelegate
            settingsViewController.captureSessionQueue = captureSessionQueue
        }
    }

    // Note that the recurring recording time text change causes this to be called each time.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Seems necessary to keep the AV Camera preview correctly sized.
        avCameraPreview.frame = arView.bounds
    }

    @IBAction func pressToggleButton(_ sender: UIButton) {
        if captureControllerDelegate.capturing() {
            // Do not allow captures shorter than one second, so that two capture sessions cannot start
            // on the same second which would give them identical filenames and cause errors.
            if let captureStartTimestamp = self.captureControllerDelegate.getCaptureStartTimestamp() {
                if (ProcessInfo.processInfo.systemUptime - captureStartTimestamp) < 1.1 {
                    return
                }
            }
            setupButtons(CaptureStatus.paused)
            captureSessionQueue.async {
                self.captureControllerDelegate.stopCapture()
            }
        }
        else {
            setupButtons(CaptureStatus.capturing)
            captureSessionQueue.async {
                self.captureControllerDelegate.startCapture()
            }
        }
    }

    private func setupButtons(_ status: CaptureStatus) {
        if status == CaptureStatus.paused {
            toggleButton.setTitle("Start", for: .normal)
            animateButtonRadius(toValue: toggleButton.frame.height / 4.0)
            toggleButton.layer.borderColor = UIColor.green.cgColor

            UIApplication.shared.isIdleTimerDisabled = false
            settingsButton.isEnabled = true
            filesButton.isEnabled = true
            aboutButton.isEnabled = true
        }
        else {
            toggleButton.setTitle("Stop", for: .normal)
            animateButtonRadius(toValue: toggleButton.frame.height / 2.0)
            toggleButton.layer.borderColor = UIColor.red.cgColor

            UIApplication.shared.isIdleTimerDisabled = true
            settingsButton.isEnabled = false
            filesButton.isEnabled = false
            aboutButton.isEnabled = false
        }
    }

    private func setUpdateTimer() {
        updateTimer?.cancel()
        updateTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        updateTimer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(10))
        updateTimer.setEventHandler { [weak self] in
            if let captureStartTimestamp = self?.captureControllerDelegate.getCaptureStartTimestamp() {
                let timestamp = ProcessInfo.processInfo.systemUptime
                self?.timeLabel.text = String(format: "Rec time: %.01f s", timestamp - captureStartTimestamp)
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

    private func animateButtonRadius(toValue: CGFloat) {
        let animation = CABasicAnimation(keyPath: "cornerRadius")
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

enum CaptureStatus {
    case paused
    case capturing
}
