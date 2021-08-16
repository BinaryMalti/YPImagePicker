//
//  CustomCropViewController.swift
//  YPImagePicker
//
//  Created by Malti Maurya on 16/08/21.
//  Copyright © 2021 Yummypets. All rights reserved.
//

import UIKit

class CropArtworkViewController: IGRPhotoTweakViewController {

    @IBOutlet weak var rotateRightButton: UIButton!
    @IBOutlet weak var rotateLeftButton: UIButton!
    @IBOutlet weak fileprivate var angleSlider: UISlider?
    @IBOutlet weak var cancelEditButton: UIButton!
    @IBOutlet weak var saveEditButton: UIButton!
    @IBOutlet weak fileprivate var angleLabel: UILabel?
    @IBOutlet weak fileprivate var straightenImageSlider: HorizontalDial? {
        didSet {
            self.straightenImageSlider?.enableRange = true
            self.straightenImageSlider?.maximumValue = 100
            self.straightenImageSlider?.minimumValue = -100
            self.straightenImageSlider?.migneticOption = .none
        }
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController!.setNavigationBarHidden(false, animated: false)
       // self.addBackButtonItem(title: "Select Artwork", saveAsDraft: false)
        self.delegate = self
        //self.lockAspectRatio(true)
        //FIXME: Zoom setup
//        self.photoView.minimumZoomScale = 1.0;
//        self.photoView.maximumZoomScale = 10.0;
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
    
    fileprivate func setupSlider() {
        self.angleSlider?.minimumValue = -Float(IGRRadianAngle.toRadians(90))
        self.angleSlider?.maximumValue = Float(IGRRadianAngle.toRadians(90))
        self.angleSlider?.value = 0.0
        
        setupAngleLabelValue(radians: CGFloat((self.angleSlider?.value)!))
    }
    
    fileprivate func setupAngleLabelValue(radians: CGFloat) {
        let intDegrees: Int = Int(IGRRadianAngle.toDegrees(radians))
        self.angleLabel?.text = "\(intDegrees)"
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
    
    @IBAction func onChandeAngleSliderValue(_ sender: UISlider) {
        let radians: CGFloat = CGFloat(sender.value)
        setupAngleLabelValue(radians: radians)
        self.changeAngle(radians: radians)
    }
    
    @IBAction func onEndTouchAngleControl(_ sender: UIControl) {
        self.stopChangeAngle()
    }
    
    var rotateLeft:CGFloat = 0.5
    @IBAction func rotateLeft(_ sender: Any) {
        self.photoView.changeAngle(radians: -rotateLeft * CGFloat.pi)
        rotateLeft = rotateLeft + 0.5
        
    }
    
    var rotateRight:CGFloat = 0.5
    @IBAction func rotateRight(_ sender: Any) {
        self.photoView.changeAngle(radians: rotateRight * CGFloat.pi)
        rotateRight = rotateRight + 0.5
    }

    @IBAction func saveCropArtwork(_ sender: Any) {
        cropAction()
    }

    
    @IBAction func cancelCropArtwork(_ sender: UIButton) {
     
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
//    override open func customGridLinesCount() -> Int {
//        return 4
//    }
//
//    override open func customCornerBorderLength() -> CGFloat {
//        return 30.0
//    }
//
    override open func customIsHighlightMask() -> Bool {
        return true
    }

    override open func customHighlightMaskAlphaValue() -> CGFloat {
        return 0.3
    }
    
    override open func customCanvasInsets() -> UIEdgeInsets {
        return UIEdgeInsets(top: UIDevice.current.orientation.isLandscape ? 40.0 : 70.0,
                            left: 0,
                            bottom: 0,
                            right: 0)
    }
}

extension CropArtworkViewController: HorizontalDialDelegate {
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
extension CropArtworkViewController: IGRPhotoTweakViewControllerDelegate{
    func photoTweaksController(_ controller: IGRPhotoTweakViewController, didFinishWithCroppedImage croppedImage: UIImage) {
        self.showArtworks(imageCrop: croppedImage)
    }
    
    func photoTweaksControllerDidCancel(_ controller: IGRPhotoTweakViewController) {
       
    }
    
    
}
