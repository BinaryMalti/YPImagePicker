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
        pictureLabel.font = YPConfig.fonts.galleryNoteFont
    }
}
