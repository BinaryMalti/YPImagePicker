//
//  CustomCropView.swift
//  YPImagePicker
//
//  Created by Malti Maurya on 16/08/21.
//

import UIKit

class CustomCropView: UIView {
    @IBOutlet weak var rotateRightButton: UIButton!
    @IBOutlet weak var rotateLeftButton: UIButton!
  //  @IBOutlet weak fileprivate var angleSlider: UISlider?
    @IBOutlet weak var cancelEditButton: UIButton!
    @IBOutlet weak var saveEditButton: UIButton!
    @IBOutlet weak var angleLabel: UILabel!
    @IBOutlet weak var straightenImageSlider: HorizontalDial!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        straightenImageSlider.enableRange = true
        straightenImageSlider.maximumValue = 45
        straightenImageSlider.minimumValue = -45
        straightenImageSlider.tick = 1.0
        straightenImageSlider.migneticOption = .ceil
    }
}

extension CustomCropView{
    class func xibView() -> CustomCropView? {
        let bundle = Bundle(for: CustomCropViewController.self)
        let nib = UINib(nibName: "CustomCropView", bundle: bundle)
        let xibView = nib.instantiate(withOwner: self, options: nil)[0] as? CustomCropView
        return xibView
    }
    
}
