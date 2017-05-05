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
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var didtakePhoto = Bool()
    let tempImageView: UIImageView = {
        let iv = UIImageView(frame: UIScreen.main.bounds)
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initSession()
        addSubview(tempImageView)
    }
    
    private func initSession() {
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        let backCamera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            if (captureSession?.canAddInput(input))! {
                captureSession?.addInput(input)
                stillImageOutput = AVCapturePhotoOutput()
                
                if (captureSession?.canAddOutput(stillImageOutput))! {
                    captureSession?.addOutput(stillImageOutput)
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
                    previewLayer?.connection.videoOrientation = .portrait
                    layer.addSublayer(previewLayer!)
                    captureSession?.startRunning()
                    previewLayer?.frame = UIScreen.main.bounds
                }
            }
        } catch let error {
            print("Error initSession: \(error)")
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CameraView: AVCapturePhotoCaptureDelegate {
    
    func didPressTakePhoto() {
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160,
                             ]
        settings.previewPhotoFormat = previewFormat
        self.stillImageOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if let error = error {
            print(error.localizedDescription)
        }
        
        guard let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer,
            let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer),
            let dataProvider = CGDataProvider(data: dataImage as CFData),
            let cgImageRef = CGImage.init(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent) else {
                print("Error on captureOutput")
                return
        }
        
        let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: .right)
        tempImageView.image = image//UIImage(data: dataImage)
        tempImageView.isHidden = false
    }
    
    func didPressTakeAnother() {
        
        if didtakePhoto {
            tempImageView.isHidden = true
            didtakePhoto = false
        } else {
            captureSession?.startRunning()
            didtakePhoto = true
            didPressTakePhoto()
        }
    }
}

