//
//  CustomCameraVC.swift
//  YPImagePickerExample
//
//  Created by Malti Maurya on 13/08/21.
//  Copyright © 2021 Octopepper. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

@available(iOS 10.0, *)
class CustomCameraViewController: UIViewController, UIGestureRecognizerDelegate {
    
    private var captureSession = AVCaptureSession()
    private var mainCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var currentDevice: AVCaptureDevice?
    
    //TODO: Must be tested AVCaptureVideoDataOutput too
    private var videoOutput: AVCaptureMovieFileOutput?
    private var isRecording: Bool = false
    private var photoOutput : AVCapturePhotoOutput?
    private var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    private var isVideoMode: Bool = false
    
    private let videoText = "🎬VideoMode now"
    private let photoText = "🤷‍♀️PhotoMode now"
    
    internal var v: CustomCameraView!

   
    
    // MARK: - Init
    
    public required init(items: [YPMediaItem]?) {
        super.init(nibName: nil, bundle: nil)
        title = YPConfig.wordings.libraryTitle
        view.backgroundColor = UIColor.white
    }
    
    public convenience init() {
        self.init(items: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    public override func loadView() {
        v = CustomCameraView.xibView()
        view = v
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCaptureSession()
        setupDevice()
        setupIOs()
        setupPreviewLayer()
        captureSession.startRunning()
        setupTapGesture()
        
        self.v.changeButton.setTitle(photoText, for: .normal)
    }
    
    @objc func tapGesture(_: UITapGestureRecognizer){
        
        if !self.isVideoMode {
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            settings.isAutoStillImageStabilizationEnabled = true
            self.photoOutput!.capturePhoto(with: settings, delegate: self)
            
            return
        }
        
        //On Video Mode.
        if !self.isRecording {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0] as String
            let filePath: String = "\(documentsDirectory)/temp.mp4"
            let fileURL = URL(fileURLWithPath: filePath)
            self.videoOutput!.startRecording(to: fileURL, recordingDelegate: self)
            
            self.isRecording = true
        }
        else {
            self.videoOutput!.stopRecording()
            self.isRecording = false
        }
    }
    
    //-MARK: Setup
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
    }
    
    func setupDevice() {
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        
        let devices = deviceDiscoverySession.devices
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                mainCamera = device
            } else if device.position == AVCaptureDevice.Position.front {
                backCamera = device
            }
        }
        
        currentDevice = mainCamera
    }
    
    func setupIOs() {
        
        let captureDeviceInput = try! AVCaptureDeviceInput(device: currentDevice!)
        captureSession.addInput(captureDeviceInput)
        
        photoOutput = AVCapturePhotoOutput()
        if #available(iOS 11.0, *) {
            photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
        } else {
            // Fallback on earlier versions
        }
        captureSession.addOutput(photoOutput!)
        
        
        videoOutput = AVCaptureMovieFileOutput()
        captureSession.addOutput(videoOutput!)
    }
    
    func setupPreviewLayer() {
        self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        
        self.cameraPreviewLayer?.frame = view.frame
        self.view.layer.insertSublayer(self.cameraPreviewLayer!, at: 0)
    }
    
    func setupTapGesture() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGesture(_:)))
        tapGestureRecognizer.delegate = self
        self.v.cameraButton.addGestureRecognizer(tapGestureRecognizer)
    }
    

}


@available(iOS 10.0, *)
extension CustomCameraViewController: AVCapturePhotoCaptureDelegate {
    
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation() {
            let uiImage = UIImage(data: imageData)
            UIImageWriteToSavedPhotosAlbum(uiImage!,nil,nil,nil)
        }
    }
}


@available(iOS 10.0, *)
extension CustomCameraViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { saved, error in }
        
    }
}

