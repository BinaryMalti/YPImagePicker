//
//  EmptyGalleryView.swift
//  YPImagePicker
//
//  Created by Keval Shah on 25/10/21.
//
import UIKit

class EmptyGalleryView: UIView, UITextFieldDelegate {
    @IBOutlet weak var postTypeDropDownTextField: TGPPickerTextField!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var cropImage: UIButton!
    @IBOutlet weak var clickButton: UIButton!
    
    class func xibView() -> EmptyGalleryView? {
        let bundle = Bundle(for: YPPickerVC.self)
        let nib = UINib(nibName: "EmptyGalleryView", bundle: bundle)
        let xibView = nib.instantiate(withOwner: self, options: nil)[0] as? EmptyGalleryView
        return xibView
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        postTypeDropDownTextField.delegate = self
        postTypeDropDownTextField.tintColor = UIColor.clear
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return false
    }
    
    
    
}
