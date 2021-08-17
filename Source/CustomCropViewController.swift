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
        view.backgroundColor = UIColor.white
        v = CustomCropView.xibView()
        let frameHeight : CGFloat = self.view.frame.height - 195
        v.frame = CGRect(x: 0, y: frameHeight, width: self.view.frame.width, height: 130)
        view.insertSubview(self.v, belowSubview: photoView)
        view.bringSubviewToFront(self.v)
        v.straightenImageSlider.delegate = self
        self.tapGesutures()

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
         self.addBackButtonItem(title: "Select Artwork", saveAsDraft: false)
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
    
    //FIXME: Themes Preview
//    override open func setupThemes() {
//
//        IGRCropLine.appearance().backgroundColor = UIColor.green
//        IGRCropGridLine.appearance().backgroundColor = UIColor.yellow
//        IGRCropCornerView.appearance().backgroundColor = UIColor.purple
//        IGRCropCornerLine.appearance().backgroundColor = UIColor.orange
//        IGRCropMaskView.appearance().backgroundColor = UIColor.blue
//        IGRPhotoContentView.appearance().backgroundColor = UIColor.gray
//        IGRPhotoTweakView.appearance().backgroundColor = UIColor.brown
//    }
    
//    fileprivate func setupSlider() {
//        self.v.angleSlider?.minimumValue = -Float(IGRRadianAngle.toRadians(90))
//        self.v.angleSlider?.maximumValue = Float(IGRRadianAngle.toRadians(90))
//        self.v.angleSlider?.value = 0.0
//
//        setupAngleLabelValue(radians: CGFloat((self.v.angleSlider?.value)!))
//    }
    
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
    
    // MARK: - Actions
//
//    @IBAction func onChandeAngleSliderValue(_ sender: UISlider) {
//        let radians: CGFloat = CGFloat(sender.value)
//        setupAngleLabelValue(radians: radians)
//        self.changeAngle(radians: radians)
//    }
//
//    @IBAction func onEndTouchAngleControl(_ sender: UIControl) {
//        self.stopChangeAngle()
//    }
    
    var rotateLft:CGFloat = 0.5
    @objc
     func rotateLeft(_ sender: Any) {
       self.photoView.changeAngle(radians: -rotateLft * CGFloat.pi)
        rotateLft = rotateLft + 0.5
        
    }
    
    var rotateRght:CGFloat = 0.5
    @objc
     func rotateRight(_ sender: Any) {
        self.photoView.changeAngle(radians: rotateRght * CGFloat.pi)
        rotateRght = rotateRght + 0.5
    }

    @objc
    func saveCropArtwork(_ sender: Any) {
        cropAction()
    }

    @objc
    func cancelCropArtwork(_ sender: UIButton) {
        self.dismissAction()
    }
    
    func showArtworks(imageCrop : UIImage){
        var artworkSetArray : [YPMediaItem] = []
        artworkSetArray.append(YPMediaItem.photo(p: YPMediaPhoto(image: imageCrop)))
        if artworkSetArray.count > 0 {
            let gallery = YPSelectionsGalleryVC(items: artworkSetArray) { _, g, _ in
                g.dismiss(animated: true, completion: nil)
            }
            let navC = UINavigationController(rootViewController: gallery)
            self.present(navC, animated: true, completion: nil)
        } else {
            print("No items selected yet.")
        }
    }
    
    func fetchImagePreview(previewImage : UIImage){
        self.delegateYP?.showCroppedImage(image: previewImage)
            didFinishCropping?(previewImage)
        self.dismiss(animated: true, completion: nil)

    }
 
    
        //FIXME: Themes Preview
//    override open func customBorderColor() -> UIColor {
//        return UIColor.red
//    }
//
//    override open func customBorderWidth() -> CGFloat {
//        return 2.0
//    }
//
//    override open func customCornerBorderWidth() -> CGFloat {
//        return 4.0
//    }
//
//    override open func customCropLinesCount() -> Int {
//        return 3
//    }
//
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
        return UIEdgeInsets(top: UIDevice.current.orientation.isLandscape ? 40.0 : 0.0,
                            left: 0,
                            bottom: 0,
                            right: 0)
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
            self.showArtworks(imageCrop: croppedImage)
        }else{
            self.fetchImagePreview(previewImage: croppedImage)
        }
    }
    
    func photoTweaksControllerDidCancel(_ controller: IGRPhotoTweakViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
}
