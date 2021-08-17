//
//  CustomCameraView.swift
//  YPImagePicker
//
//  Created by Malti Maurya on 16/08/21.
//

import UIKit

class CustomCameraView: UIView{
    
    @IBOutlet weak var cameraButton: UIView!
    @IBOutlet weak var changeButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}
@available(iOS 10.0, *)
extension CustomCameraView {
    class func xibView() -> CustomCameraView? {
        let bundle = Bundle(for: CustomCameraViewController.self)
        let nib = UINib(nibName: "CustomCameraView", bundle: bundle)
        let xibView = nib.instantiate(withOwner: self, options: nil)[0] as? CustomCameraView
        return xibView
    }
}
