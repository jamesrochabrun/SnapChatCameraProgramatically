//
//  CameraView.swift
//  SnapCloneProgramatically
//
//  Created by James Rochabrun on 5/5/17.
//  Copyright © 2017 James Rochabrun. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation


class CameraView: UIView  {
    
    private var movieFileOutput: AVCaptureMovieFileOutput? = nil

    var captureSession = AVCaptureSession()
    var stillImageOutput = AVCapturePhotoOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var didtakePhoto = Bool()
    var isFront = false
    let tempImageView: UIImageView = {
        let iv = UIImageView(frame: UIScreen.main.bounds)
        return iv
    }()
    fileprivate let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil) // Communicate with the session and other session objects on this queue.
    fileprivate var inProgressPhotoCaptureDelegates = [Int64 : PhotoCaptureDelegate]()
    
    // MARK: Session Management
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    private var setupResult: SessionSetupResult = .success
    var videoDeviceInput: AVCaptureDeviceInput!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSession()
        addSubview(tempImageView)
        addSubview(flipCameraButton)
        addSubview(captureButton)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: ISSUE 1 NOT FORGET TO REMOVE THE STARTRUNING FROM HERE
    private func configureSession() {
        
        if setupResult != .success { return }
        
      //  captureSession.beginConfiguration()
     //   captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        // Add video input.

        do {
            
            var defaultVideoDevice: AVCaptureDevice?
            
            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDuoCamera, mediaType: AVMediaTypeVideo, position: .back) {
                defaultVideoDevice = dualCameraDevice
            }
            else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
                // If the back dual camera is not available, default to the back wide angle camera.
                defaultVideoDevice = backCameraDevice
            }
            else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
                // In some cases where users break their phones, the back wide angle camera is not available. In this case, we should default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                DispatchQueue.main.async {
                    /*
                     Why are we dispatching this to the main queue?
                     Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
                     can only be manipulated on the main thread.
                     Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                     
                     Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = statusBarOrientation.videoOrientation {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    
                    self.previewLayer?.connection.videoOrientation = initialVideoOrientation
                }
                
            } else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                captureSession.commitConfiguration()
                return
            }
        } catch let error {
            print("Error configureSession: \(error)")
            setupResult = .configurationFailed
            captureSession.commitConfiguration()
        }
        
        // Add photo output.
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
            stillImageOutput.isHighResolutionCaptureEnabled = true
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
            previewLayer?.connection.videoOrientation = .portrait
            layer.addSublayer(previewLayer!)
            captureSession.startRunning()
            previewLayer?.frame = UIScreen.main.bounds
        }
        
       // captureSession.commitConfiguration()
    }
    
    // MARK: Device Configuration
    
    lazy var flipCameraButton: UIButton = {
        let button = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 70, y: 15, width: 55, height: 55))
        button.addTarget(self, action: #selector(changeCamera), for: .touchUpInside)
        button.setImage(#imageLiteral(resourceName: "flip").withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    lazy var captureButton: UIButton = {
        let button = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 85) / 2, y: UIScreen.main.bounds.height - 110, width: 85, height: 85))
        button.addTarget(self, action: #selector(didPressTakeAnother), for: .touchUpInside)
       // button.setImage(#imageLiteral(resourceName: "whiteJoystick").withRenderingMode(.alwaysTemplate), for: .normal)
        button.setImage(#imageLiteral(resourceName: "whiteJoystick"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private let videoDeviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDuoCamera], mediaType: AVMediaTypeVideo, position: .unspecified)!
    
    @objc private func changeCamera() {
        
        flipCameraButton.isEnabled = false
        captureButton.isEnabled = false
        sessionQueue.async {
            
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice!.position
            
            let preferredPosition: AVCaptureDevicePosition
            let preferredDeviceType: AVCaptureDeviceType
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInDuoCamera
                self.isFront = false
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInWideAngleCamera
                self.isFront = true
            }
            
            let devices = self.videoDeviceDiscoverySession.devices!
            var newVideoDevice: AVCaptureDevice? = nil
            
            // First, look for a device with both the preferred position and device type. Otherwise, look for a device with only the preferred position.
            if let device = devices.filter({ $0.position == preferredPosition && $0.deviceType == preferredDeviceType }).first {
                newVideoDevice = device
            }
            else if let device = devices.filter({ $0.position == preferredPosition }).first {
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.captureSession.beginConfiguration()
                    
                    // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
                    self.captureSession.removeInput(self.videoDeviceInput)
                    
                    if self.captureSession.canAddInput(videoDeviceInput) {
                        //                        NotificationCenter.default.removeObserver(self, name: Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification"), object: currentVideoDevice!)
                        //
                        //                        NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: Notification.Name("AVCaptureDeviceSubjectAreaDidChangeNotification"), object: videoDeviceInput.device)
                        
                        self.captureSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    }
                    else {
                        self.captureSession.addInput(self.videoDeviceInput);
                    }
                    
                    if let connection = self.movieFileOutput?.connection(withMediaType: AVMediaTypeVideo) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    
                    /*
                     Set Live Photo capture enabled if it is supported. When changing cameras, the
                     `isLivePhotoCaptureEnabled` property of the AVCapturePhotoOutput gets set to NO when
                     a video device is disconnected from the session. After the new video device is
                     added to the session, re-enable Live Photo capture on the AVCapturePhotoOutput if it is supported.
                     */
                    //  self.stillImageOutput.isLivePhotoCaptureEnabled = self.stillImageOutput.isLivePhotoCaptureSupported;
                    self.captureSession.commitConfiguration()
                }
                catch {
                    print("Error occured while creating video device input: \(error)")
                }
            }
            DispatchQueue.main.async {
                self.flipCameraButton.isEnabled = true
                self.captureButton.isEnabled = true
            }
        }
    }
}

extension CameraView {
    
    func didPressTakePhoto() {
        
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160,
                             ]
        settings.previewPhotoFormat = previewFormat
        
        let photoCaptureDelegate = PhotoCaptureDelegate(with: settings, capturedPhoto: { [unowned self] (cgImage) in
            
            let orientation: UIImageOrientation = self.isFront ? .leftMirrored : .right
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
            self.tempImageView.image = image
            self.tempImageView.isHidden = false
            }, completed: { [unowned self] (photoCaptureDelegate) in
                // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                self.inProgressPhotoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = nil
        })
        
        /*
         The Photo Output keeps a weak reference to the photo capture delegate so
         we store it in an array to maintain a strong reference to this object
         until the capture is completed.
         */
        self.inProgressPhotoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = photoCaptureDelegate
        self.stillImageOutput.capturePhoto(with: settings, delegate: photoCaptureDelegate)
    }
    
    func didPressTakeAnother() {
        
        if didtakePhoto {
            tempImageView.isHidden = true
            didtakePhoto = false
            flipCameraButton.isEnabled = true
        } else {
            captureSession.startRunning()
            didtakePhoto = true
            flipCameraButton.isEnabled = false
            didPressTakePhoto()
        }
    }
}














