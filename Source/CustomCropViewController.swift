//
//  CustomCropViewController.swift
//  YPImagePicker
//
//  Created by Malti Maurya on 16/08/21.
//  Copyright © 2021 Yummypets. All rights reserved.
//

import UIKit
import Stevia

class CustomCropViewController: IGRPhotoTweakViewController {

    internal var v: CustomCropView!
    var fromCamera = false
    public var didFinishCropping: ((UIImage) -> Void)?
    weak var delegateYP : YPLibraryDelegate?
    // MARK: - Init
    
    public required init(item: UIImage) {
        super.init(nibName: nil, bundle: nil)
        image = item
        title = ""
        view.backgroundColor = UIColor.black
        v = CustomCropView.xibView()
        let frameHeight : CGFloat = self.view.frame.height - 195
        v.frame = CGRect(x: 0, y: frameHeight, width: self.view.frame.width, height: 170)
        view.insertSubview(self.v, belowSubview: photoView)
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.photoView.topAnchor.constraint(equalTo: view.topAnchor, constant:0),
            v.topAnchor.constraint(equalTo: photoView.bottomAnchor,constant: 0),
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
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        self.addBackButtonItem(title: "Select Artwork", saveAsDraft: false, isFromcrop: true, isForEdit: false)
        if UIDevice.current.screenType == UIDevice.ScreenType.iPhones_6_6s_7_8 {
            self.photoView.scrollView.contentInset.top = self.photoView.scrollView.contentInset.top - 30.0
        }else if UIDevice.current.screenType == UIDevice.ScreenType.iPhones_12{
            self.photoView.scrollView.contentInset.top = self.photoView.scrollView.contentInset.top - 64.0
        }else{
            self.photoView.scrollView.contentInset.top = self.photoView.scrollView.contentInset.top - 44.0
        }

        self.view.backgroundColor = .black
        //self.lockAspectRatio(true)
        //FIXME: Zoom setup
//        self.photoView.minimumZoomScale = 1.0;
//        self.photoView.maximumZoomScale = 10.0;
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }
    
    private func tapGesutures(){
        v.saveEditButton.addTarget(self, action: #selector(saveCropArtwork(_:)), for: .touchUpInside)
        v.cancelEditButton.addTarget(self, action: #selector(cancelCropArtwork(_:)), for: .touchUpInside)
        v.rotateLeftButton.addTarget(self, action: #selector(rotateLeft(_:)), for: .touchUpInside)
        v.rotateRightButton.addTarget(self, action: #selector(rotateRight(_:)), for: .touchUpInside)
    }
    
    fileprivate func setupAngleLabelValue(radians: CGFloat) {
        let intDegrees: Int = Int(IGRRadianAngle.toDegrees(radians))
        self.v.angleLabel.text = "\(intDegrees)"
    }
    
    // MARK: - Rotation
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            self.view.layoutIfNeeded()
        }) { (context) in
            //
        }
    }
    
    var rotate = IGRRadianAngle.toRadians(0)
    
    @objc
     func rotateLeft(_ sender: Any) {
        rotate =  rotate - IGRRadianAngle.toRadians(90)
       self.photoView.changeRotateAngle(radians:rotate)
    }
    
    @objc
     func rotateRight(_ sender: Any) {
        rotate =  rotate + IGRRadianAngle.toRadians(90)
        self.photoView.changeRotateAngle(radians: rotate) //2(n-1)
    }

    @objc
    func saveCropArtwork(_ sender: Any) {
        cropAction()
    }

    @objc
    func cancelCropArtwork(_ sender: UIButton) {
        let alert = UIAlertController(title: "Discard Changes", message: "You cannot undo this action", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
                alert.dismiss(animated: true, completion: nil)
            }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction!) in
            self.dismissAction()
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
//    func showArtworks(imageCrop : UIImage){
//        var artworkSetArray : [YPMediaItem] = []
//        artworkSetArray.append(YPMediaItem.photo(p: YPMediaPhoto(image: imageCrop)))
//        if artworkSetArray.count > 0 {
//            let gallery = YPSelectionsGalleryVC(items: artworkSetArray) { _, g, _ in
//                g.dismiss(animated: true, completion: nil)
//            }
//            let navC = UINavigationController(rootViewController: gallery)
//            self.present(navC, animated: true, completion: nil)
//        } else {
//            print("No items selected yet.")
//        }
//    }
    

    func fetchImagePreview(previewImage: UIImage) {
        self.delegateYP?.showCroppedImage(rect: self.photoView.cropView.frame, image: previewImage)
       // didFinishCropping?(previewImage)
        self.navigationController?.popViewController(animated: true)
       // self.dismiss(animated: true, completion: nil)

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
        if UIDevice.current.screenType == UIDevice.ScreenType.iPhones_6_6s_7_8 {
            return UIEdgeInsets(top: 35.0,
                                left: 0,
                                bottom: 35.0,
                                right: 0)
        }else if UIDevice.current.screenType == UIDevice.ScreenType.iPhones_12{
            return UIEdgeInsets(top: 69.0,
                                left: 0,
                                bottom: 69.0,
                                right: 0)
        }else{
            return UIEdgeInsets(top: 49.0,
                                left: 0,
                                bottom: 49.0,
                                right: 0)
        }
        
    }
}

extension CustomCropViewController: HorizontalDialDelegate {
    func horizontalDialDidValueChanged(_ horizontalDial: HorizontalDial) {
        let degrees = horizontalDial.value
        let radians = IGRRadianAngle.toRadians(CGFloat(degrees))
        self.setupAngleLabelValue(radians: radians)
        self.changeAngle(radians: radians)
    }
    
    func horizontalDialDidEndScroll(_ horizontalDial: HorizontalDial) {
        self.stopChangeAngle()
    }
}


// MARK: IGRPhotoTweak Delegate
extension CustomCropViewController: IGRPhotoTweakViewControllerDelegate{
    func photoTweaksController(_ controller: IGRPhotoTweakViewController, didFinishWithCroppedImage croppedImage: UIImage) {
        if fromCamera {
            self.didFinishCropping?(croppedImage)
           // self.showArtworks(imageCrop: croppedImage)
        }else{
            self.fetchImagePreview(previewImage: croppedImage)
        }
    }
    
    
    func photoTweaksControllerDidCancel(_ controller: IGRPhotoTweakViewController) {
        self.dismiss(animated: true, completion: nil)
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
