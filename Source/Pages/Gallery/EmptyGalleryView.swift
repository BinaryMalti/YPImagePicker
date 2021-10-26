//
//  EmptyGalleryView.swift
//  YPImagePicker
//
//  Created by Keval Shah on 25/10/21.
//

import UIKit

class EmptyGalleryView: UIView {
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    class func xibView() -> EmptyGalleryView? {
        let bundle = Bundle(for: YPPickerVC.self)
        let nib = UINib(nibName: "EmptyGalleryView", bundle: bundle)
        let xibView = nib.instantiate(withOwner: self, options: nil)[0] as? EmptyGalleryView
        return xibView
    }
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}
