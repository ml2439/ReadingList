import UIKit
import AVFoundation
import SVProgressHUD

class NonRotatingNavigationController: ThemedNavigationController {
    override var shouldAutorotate: Bool {
        // Correctly laying out the preview layer during interface rotation is tricky. Just disable it.
        return false
    }
}

class ScanBarcode: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    let feedbackGenerator = UINotificationFeedbackGenerator()

    @IBOutlet private weak var cameraPreviewView: UIView!
    @IBOutlet private weak var previewOverlay: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        feedbackGenerator.prepare()

        // Setup the camera preview asynchronously
        DispatchQueue.main.async {
            self.setupAvSession()
            self.previewOverlay.layer.borderColor = UIColor.red.cgColor
            self.previewOverlay.layer.borderWidth = 1.0
        }
    }

    @IBAction private func cancelWasPressed(_ sender: AnyObject) {
        SVProgressHUD.dismiss()
        dismiss(animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        cameraPreviewView.layoutIfNeeded()

        if session?.isRunning == false {
            session!.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if session?.isRunning == true {
            session!.stopRunning()
        }
    }

    private func setupAvSession() {
        #if DEBUG
        if DebugSettings.useFixedBarcodeScanImage {
            useExampleBarcodeImage()
        }
        switch DebugSettings.barcodeScanSimulation {
        case .none:
            break
        case .normal:
            // In "normal" mode we want to ignore any actual errors, like not having a camera
            return
        case .validIsbn:
            respondToCapturedIsbn("9781781100264")
            return
        case .unfoundIsbn:
            // Use a string which isn't an ISBN
            respondToCapturedIsbn("9781111111111")
            return
        case .existingIsbn:
            respondToCapturedIsbn(DebugSettings.existingIsbn)
            return
        case .noCameraPermissions:
            presentCameraPermissionsAlert()
            return
        }
        #endif

        guard let camera = AVCaptureDevice.default(for: AVMediaType.video), let input = try? AVCaptureDeviceInput(device: camera) else {
            presentCameraPermissionsAlert(); return
        }

        // Try to focus the camera if possible
        if camera.isFocusPointOfInterestSupported == true {
            try? camera.lockForConfiguration()
            camera.focusPointOfInterest = cameraPreviewView.center
        }

        let output = AVCaptureMetadataOutput()
        session = AVCaptureSession()

        // Check that we can add the input and output to the session
        guard session!.canAddInput(input) && session!.canAddOutput(output) else {
            presentInfoAlert(title: "Error ⚠️", message: "The camera could not be used. Sorry about that.")
            feedbackGenerator.notificationOccurred(.error); return
        }

        // Prepare the metadata output and add to the session
        session!.addInput(input)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
        session!.addOutput(output)

        // This line must be after session outputs are added
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.ean13]

        // Begin the capture session.
        session!.startRunning()

        // We want to view what the camera is seeing
        previewLayer = AVCaptureVideoPreviewLayer(session: session!)
        previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer!.frame = view.bounds
        setVideoOrientation()

        cameraPreviewView.layer.addSublayer(previewLayer!)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        setVideoOrientation()
    }

    private func setVideoOrientation() {
        guard let connection = previewLayer?.connection, connection.isVideoOrientationSupported else { return }

        if let videoOrientation = UIDevice.current.orientation.videoOrientation {
            connection.videoOrientation = videoOrientation
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        guard let avMetadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let isbn = ISBN13(avMetadata.stringValue) else { return }
        DispatchQueue.main.sync {
            respondToCapturedIsbn(isbn.string)
        }
    }

    func respondToCapturedIsbn(_ isbn: String) {
        feedbackGenerator.prepare()

        // Since we have a result, stop the session and hide the preview
        session?.stopRunning()

        // Check that the book hasn't already been added
        if let existingBook = Book.get(fromContext: PersistentStoreManager.container.viewContext, isbn: isbn) {
            feedbackGenerator.notificationOccurred(.warning)
            presentDuplicateAlert(existingBook)
        } else {
            feedbackGenerator.notificationOccurred(.success)
            searchForFoundIsbn(isbn: isbn)
        }
    }

    func presentDuplicateAlert(_ book: Book) {
        let alert = duplicateBookAlertController(goToExistingBook: {
            self.dismiss(animated: true) {
                appDelegate.tabBarController.simulateBookSelection(book, allowTableObscuring: true)
            }
        }, cancel: {
            self.session?.startRunning()
        })

        present(alert, animated: true)
    }

    func searchForFoundIsbn(isbn: String) {

        // We're going to be doing a search online, so bring up a spinner
        SVProgressHUD.show(withStatus: "Searching...")

        GoogleBooks.fetch(isbn: isbn)
            .catch(on: .main) { error in
                self.feedbackGenerator.notificationOccurred(.error)
                switch error {
                case GoogleError.noResult: self.presentNoExactMatchAlert(forIsbn: isbn)
                default: self.onSearchError(error)
                }
            }
            .then(on: .main) { fetchResult in
                // self is weak since the barcode callback is on another thread, and it is possible (with careful timing)
                // to get the view controller to dismiss after the barcode has been detected but before the callback runs.
                if let existingBook = Book.get(fromContext: PersistentStoreManager.container.viewContext, googleBooksId: fetchResult.id) {
                    self.feedbackGenerator.notificationOccurred(.warning)
                    self.presentDuplicateAlert(existingBook)
                } else {
                    self.feedbackGenerator.notificationOccurred(.success)

                    // Event logging
                    UserEngagement.logEvent(.scanBarcode)

                    // If there is no duplicate, we can safely go to the next page
                    let context = PersistentStoreManager.container.viewContext.childContext()
                    let book = Book(context: context, readState: .toRead)
                    book.populate(fromFetchResult: fetchResult)
                    self.navigationController!.pushViewController(
                        EditBookReadState(newUnsavedBook: book, scratchpadContext: context),
                        animated: true)
                }
            }
    }

    func presentNoExactMatchAlert(forIsbn isbn: String) {
        let alert = UIAlertController(title: "No Exact Match",
                                      message: "We couldn't find an exact match. Would you like to do a more general search instead?",
                                      preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.cancel) { _ in
            self.session?.startRunning()
        })
        alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) { _ in
            let presentingViewController = self.presentingViewController
            self.dismiss(animated: true) {
                let searchOnlineNav = Storyboard.SearchOnline.rootAsFormSheet() as! UINavigationController
                (searchOnlineNav.viewControllers.first as! SearchOnline).initialSearchString = isbn
                presentingViewController!.present(searchOnlineNav, animated: true, completion: nil)
            }
        })
        present(alert, animated: true, completion: nil)
    }

    func onSearchError(_ error: Error) {
        var message: String!
        switch (error as NSError).code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            message = "There seems to be no internet connection."
        default:
            message = "Something went wrong when searching online. Maybe try again?"
        }
        presentInfoAlert(title: "Error ⚠️", message: message)
    }

    func presentInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { _ in
            self.dismiss(animated: true, completion: nil)
        })
        present(alert, animated: true, completion: nil)
    }

    func presentCameraPermissionsAlert() {
        let alert = UIAlertController(title: "Permission Required", message: "You'll need to change your settings to allow Reading List to use your device's camera.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Settings", style: UIAlertActionStyle.default) { _ in
            if let appSettings = URL(string: UIApplicationOpenSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
                UIApplication.shared.open(appSettings, options: [:])
                self.dismiss(animated: false)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { _ in
            self.dismiss(animated: true)
        })
        feedbackGenerator.notificationOccurred(.error)
        present(alert, animated: true, completion: nil)
    }

    #if DEBUG

    func useExampleBarcodeImage() {
        let imageView = UIImageView(frame: view.frame)
        imageView.contentMode = .scaleAspectFill
        imageView.image = #imageLiteral(resourceName: "example_barcode.jpg")
        view.addSubview(imageView)
        imageView.addSubview(previewOverlay)
    }

    #endif
}
