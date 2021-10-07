//
//  CustomCropNavigationBarView.swift
//  YPImagePicker
//
//  Created by Malti Maurya on 27/09/21.
//

import UIKit

class CustomCropNavigationBarView: UIView {
    //
    @IBOutlet weak var backButton: UIButton!
    override func awakeFromNib() {
        super.awakeFromNib()
        backButton.setImage(YPConfig.icons.backButtonIcon, for: .normal)
        backButton.tintColor = .black
        backButton.sizeToFit()
        backButton.setTitleColor(.black, for: .normal)
        backButton.titleLabel?.font = YPConfig.fonts.leftBarButtonFont
        backButton.titleLabel!.textColor = .black
    }
    
 
}
extension CustomCropNavigationBarView{
    class func xibView() -> CustomCropNavigationBarView? {
        let bundle = Bundle(for: CustomCropViewController.self)
        let nib = UINib(nibName: "CustomCropNavigationBarView", bundle: bundle)
        let xibView = nib.instantiate(withOwner: self, options: nil)[0] as? CustomCropNavigationBarView
        return xibView
    }
    
}
