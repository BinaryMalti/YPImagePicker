//
//  CustomCropViewController.swift
//  YPImagePicker
//
//  Created by Malti Maurya on 16/08/21.
//  Copyright © 2021 Yummypets. All rights reserved.
//

import Stevia
import UIKit

class CustomCropViewController: IGRPhotoTweakViewController {
    internal var v: CustomCropView!
    internal var navbarView: CustomCropNavigationBarView!
    var fromCamera = false
    public var didFinishCropping: ((UIImage) -> Void)?
    weak var delegateYP: YPLibraryDelegate?
    var straighteningValue: CGFloat = 0.0

    // MARK: - Init
    
    public required init(item: UIImage) {
        super.init(nibName: nil, bundle: nil)
        image = item
        title = ""
        view.backgroundColor = UIColor.black
        v = CustomCropView.xibView()
        navbarView = CustomCropNavigationBarView.xibView()
        let frameHeight: CGFloat = self.view.frame.height - 195
        v.frame = CGRect(x: 0, y: frameHeight, width: self.view.frame.width, height: 170)
        view.insertSubview(self.v, belowSubview: photoView)
        view.addSubview(navbarView)
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navbarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navbarView.leftAnchor.constraint(equalTo: view.leftAnchor),
            navbarView.rightAnchor.constraint(equalTo: view.rightAnchor),
            navbarView.heightAnchor.constraint(equalToConstant: 69),
            self.photoView.topAnchor.constraint(equalTo: view.topAnchor),
            v.topAnchor.constraint(equalTo: photoView.bottomAnchor),
            v.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor),
            v.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            v.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
        ])
        v.straightenImageSlider.delegate = self
        self.tapGesutures()
        view.bringSubviewToFront(self.v)
        view.setNeedsLayout()
    }
    
    public convenience init() {
        self.init()
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        self.view.backgroundColor = .black
        // self.lockAspectRatio(true)
        // FIXME: Zoom setup
//        self.photoView.minimumZoomScale = 1.0;
//        self.photoView.maximumZoomScale = 10.0;
    }

    override func backButtonClick(sender: UIButton) {
        let alert = UIAlertController(title: "Discard changes", message: "You will loose all the edits performed", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive, handler: { _ in
            self.dismiss(animated: true, completion: nil)
            self.navigationController?.popViewController(animated: true)
        }))
          
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: {
            print("completion block")
        })
    }
    
    private func tapGesutures() {
        v.saveEditButton.addTarget(self, action: #selector(saveCropArtwork(_:)), for: .touchUpInside)
        navbarView.backButton.addTarget(self, action: #selector(backButtonClick(sender:)), for: .touchUpInside)
        v.cancelEditButton.addTarget(self, action: #selector(cancelCropArtwork(_:)), for: .touchUpInside)
        v.rotateLeftButton.addTarget(self, action: #selector(rotateLeft(_:)), for: .touchUpInside)
        v.rotateRightButton.addTarget(self, action: #selector(rotateRight(_:)), for: .touchUpInside)
    }
    
    fileprivate func setupAngleLabelValue(radians: CGFloat) {
        let intDegrees = Int(IGRRadianAngle.toDegrees(radians))
        self.v.angleLabel.text = "\(intDegrees)"
    }
    
    // MARK: - Rotation
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
            self.view.layoutIfNeeded()
        }) { _ in
            //
        }
    }
    
    var rotate = IGRRadianAngle.toRadians(0)
    
    @objc
    func rotateLeft(_ sender: Any) {
        rotate = (rotate + straighteningValue) - IGRRadianAngle.toRadians(90)
        self.photoView.changeRotateAngle(radians: rotate)
    }
    
    @objc
    func rotateRight(_ sender: Any) {
        rotate = (rotate + straighteningValue) + IGRRadianAngle.toRadians(90)
        self.photoView.changeRotateAngle(radians: rotate) // 2(n-1)
    }

    @objc
    func saveCropArtwork(_ sender: Any) {
        cropAction()
    }

    @objc
    func cancelCropArtwork(_ sender: UIButton) {
        let alert = UIAlertController(title: "Discard Changes", message: "You will loose all the edits performed", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            alert.dismiss(animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive, handler: { (_: UIAlertAction!) in
            self.dismissAction()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    func fetchImagePreview(previewImage: UIImage) {
        self.delegateYP?.showCroppedImage(rect: self.photoView.cropView.frame, image: previewImage)
        self.navigationController?.popViewController(animated: true)
    }
 
    override open func customGridLinesCount() -> Int {
        return 4
    }

    override open func customCornerBorderLength() -> CGFloat {
        return 30.0
    }

    override open func customIsHighlightMask() -> Bool {
        return true
    }

    override open func customHighlightMaskAlphaValue() -> CGFloat {
        return 0.3
    }

    override open func customCanvasInsets() -> UIEdgeInsets {
        return UIEdgeInsets(top: UIDevice.current.orientation.isLandscape ? 40.0 : 100.0,
                            left: 12,
                            bottom: 30,
                            right: 12)
    }
}

extension CustomCropViewController: HorizontalDialDelegate {
    func horizontalDialDidValueChanged(_ horizontalDial: HorizontalDial) {
        let degrees = horizontalDial.value
        let radians = IGRRadianAngle.toRadians(CGFloat(degrees))
        self.straighteningValue = radians
        self.setupAngleLabelValue(radians: radians)
        self.changeAngle(radians: radians)
    }
    
    func horizontalDialDidEndScroll(_ horizontalDial: HorizontalDial) {
        self.stopChangeAngle()
    }
}

// MARK: IGRPhotoTweak Delegate

extension CustomCropViewController: IGRPhotoTweakViewControllerDelegate {
    func photoTweaksController(_ controller: IGRPhotoTweakViewController, didFinishWithCroppedImage croppedImage: UIImage) {
        if fromCamera {
            self.didFinishCropping?(croppedImage)
        } else {
            self.fetchImagePreview(previewImage: croppedImage)
        }
    }
    
    func photoTweaksControllerDidCancel(_ controller: IGRPhotoTweakViewController) {
        self.navigationController?.popViewController(animated: true)
    }
}

extension UIDevice {
    var iPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }

    enum ScreenType: String {
        case iPhones_6_6s_7_8 = "iPhone 6, iPhone 6S, iPhone 7 or iPhone 8"
        case iPhones_6Plus_6sPlus_7Plus_8Plus = "iPhone 6 Plus, iPhone 6S Plus, iPhone 7 Plus or iPhone 8 Plus"
        case iPhones_12 = "iPhone 12"
        case unknown
    }

    var screenType: ScreenType {
        switch UIScreen.main.nativeBounds.height {
        case 1334:
            return .iPhones_6_6s_7_8
        case 1920, 2208:
            return .iPhones_6Plus_6sPlus_7Plus_8Plus
        case 2532:
            return .iPhones_12
        default:
            return .unknown
        }
    }
}
