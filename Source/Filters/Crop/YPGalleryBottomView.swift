//
//  YPGalleryBottomView.swift
//  YPImagePicker
//
//  Created by Malti Maurya on 22/07/21.
//

import UIKit

class YPGalleryBottomView: UIView {
    
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var pictureLabel: UILabel!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longString = pictureLabel.text!
        let longestWord = "picture (01) "
        let longestWordRange = (longString as NSString).range(of: longestWord)
        let attributedString = NSMutableAttributedString(string: longString, attributes: [NSAttributedString.Key.font : YPConfig.fonts.galleryNoteFont])
        attributedString.setAttributes([NSAttributedString.Key.font : YPConfig.fonts.pickerTitleFont, NSAttributedString.Key.foregroundColor : UIColor.black], range: longestWordRange)
        pictureLabel.attributedText = attributedString
    }
}
