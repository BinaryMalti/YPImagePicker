//
//  YPLibrarySelection.swift
//  YPImagePicker
//
//  Created by Sacha DSO on 18/04/2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit

struct YPLibrarySelection {
    let index: Int
    var cropRect: CGRect?
    var cutWidth: CGFloat
    var cutHeight: CGFloat
    var scrollViewContentOffset: CGPoint?
    var scrollViewZoomScale: CGFloat?
    let assetIdentifier: String?
    
    init(index: Int,
         cropRect: CGRect? = nil,
         scrollViewContentOffset: CGPoint? = nil,
         scrollViewZoomScale: CGFloat? = nil,
         assetIdentifier: String?,cutWidth: CGFloat, cutHeight:CGFloat) {
        self.index = index
        self.cropRect = cropRect
        self.scrollViewContentOffset = scrollViewContentOffset
        self.scrollViewZoomScale = scrollViewZoomScale
        self.assetIdentifier = assetIdentifier
        self.cutWidth = cutWidth
        self.cutHeight = cutHeight
    }
}
