//
//  YPImagePicker.swift
//  YPImgePicker
//
//  Created by Sacha Durand Saint Omer on 27/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

public protocol YPImagePickerDelegate: AnyObject {
    func noPhotos()
    func shouldAddToSelection(indexPath: IndexPath, numSelections: Int) -> Bool
}

open class YPImagePicker: UINavigationController,YPLibraryDelegate {
 
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    func showCroppedImage(rect: CGRect) {
        self.picker.libraryVC?.updateImageCrop(cropRect: rect)
    }

    private var _didFinishPicking: ((Int,[YPMediaItem], Bool) -> Void)?
    private var _didLoadDraftImages: (([UIImage], Bool) -> Void)?
    public func didFinishPicking(completion: @escaping (_ clickType: Int,_ items: [YPMediaItem], _ cancelled: Bool) -> Void) {
        _didFinishPicking = completion
    }
    public func loadDraftImage(completion: @escaping (_ items: [UIImage], _ cancelled: Bool) -> Void) {
        _didLoadDraftImages = completion
    }
    public weak var imagePickerDelegate: YPImagePickerDelegate?
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return YPImagePickerConfiguration.shared.preferredStatusBarStyle
    }
    
    // This nifty little trick enables us to call the single version of the callbacks.
    // This keeps the backwards compatibility keeps the api as simple as possible.
    // Multiple selection becomes available as an opt-in.
    private func didSelect(items: [YPMediaItem],draftItem: [UIImage], clickType:Int) {
        if clickType == 1{
            _didLoadDraftImages?(draftItem,false)
        }else{
            _didFinishPicking?(clickType, items, false)
        }
    }
    
    let loadingView = YPLoadingView()
    private let picker: YPPickerVC!
    
    /// Get a YPImagePicker instance with the default configuration.
    public convenience init() {
        self.init(configuration: YPImagePickerConfiguration.shared)
    }
    
    /// Get a YPImagePicker with the specified configuration.
    public required init(configuration: YPImagePickerConfiguration) {
        YPImagePickerConfiguration.shared = configuration
        picker = YPPickerVC()
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen // Force .fullScreen as iOS 13 now shows modals as cards by default.
        picker.imagePickerDelegate = self
        navigationBar.tintColor = .ypLabel
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
override open func viewDidLoad() {
        super.viewDidLoad()
        picker.didClose = { [weak self] in
            self?._didFinishPicking?(0,[], true)
        }
        viewControllers = [picker]
        setupLoadingView()
        navigationBar.isTranslucent = false
    
        picker.didSelectDraftItems = {[weak self] drafts in
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.fade
            self?.view.layer.add(transition, forKey: nil)
            if drafts.count > 0{
                self?.didSelect(items: [], draftItem: drafts, clickType: 1)
            }
            
        }
        picker.didSelectItems = { [weak self] items in
            // Use Fade transition instead of default push animation
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.fade
            self?.view.layer.add(transition, forKey: nil)
            
            // Multiple items flow
            if items.count > 0 {
                if YPConfig.library.skipSelectionsGallery {
                    if self?.picker.libraryVC?.v.showDraftImages == true{
                        self?.didSelect(items: items, draftItem: [], clickType: 1)
                    }else{
                    self?.didSelect(items: items, draftItem: [], clickType: 0)
                    }
                    return
                }else {
                    if self?.picker.libraryVC?.v.showDraftImages == true{
                        self?.didSelect(items: items,
                                        draftItem: self?.picker.libraryVC?.v.draftImages ?? [], clickType: 0)
                        return
                    }else if self?.picker.libraryVC?.fromCamera == true{
                        let selectionsGalleryVC = YPSelectionsGalleryVC(items: self!.arrangeArtworkData(items: items)) { _, _, items in
                            self?.didSelect(items: items, draftItem: [], clickType: 2)
                        }
                        let sideMargin: CGFloat = 24
                        let overlapppingNextPhoto: CGFloat = 37
                        let screenWidth = YPImagePickerConfiguration.screenWidth
                        let size = screenWidth - (sideMargin + overlapppingNextPhoto)
                        let item = items.first!
                        switch item {
                        case .photo(let photo):
                          let imageRatio =  self!.calculateSingleImageSize(image: photo.image, size: size)
                            selectionsGalleryVC.cropWidth = imageRatio.width
                            selectionsGalleryVC.cropHeight = imageRatio.height
                        case .video(_):break
                        }
                        self?.pushViewController(selectionsGalleryVC, animated: true)
                        return
                    }
                    else if self?.picker.libraryVC?.fromCropClick == true{
                        let item = items.first!
                        switch item {
                        case .photo(let photo):
                            let completion = { (photo: YPMediaPhoto) in
                                let mediaItem = YPMediaItem.photo(p: photo)
                                self?.didSelect(items: [mediaItem], draftItem: [], clickType: 3)
                            }
                            func showCropVC(photo: YPMediaPhoto, completion: @escaping (_ aphoto: YPMediaPhoto) -> Void) {
                                    let cropVC = CustomCropViewController(item: photo.image)
                                cropVC.fromCamera = self!.picker.libraryVC!.fromCamera
                                    cropVC.didFinishCropping = { croppedImage in
                                        photo.modifiedImage = croppedImage
                                        completion(photo)
                                    }
                                cropVC.delegateYP = self
                                let navVC = UINavigationController(rootViewController: cropVC)
                                navVC.view.backgroundColor = .white
                                navVC.toolbar.isHidden = true
                                navVC.navigationBar.tintColor = .black
                                navVC.navigationBar.backgroundColor = .white
                                navVC.navigationBar.shadowImage = UIImage()
                                navVC.navigationBar.isTranslucent = false
                                navVC.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.compact)
                                navVC.modalPresentationStyle = .fullScreen
                                self?.present(navVC, animated: true, completion: nil)
                            }
                            showCropVC(photo: photo, completion: completion)
                        case .video(_):
                            break
                        }
                        return
                    }
                    else{
                        let selectionsGalleryVC = YPSelectionsGalleryVC(items: self!.arrangeArtworkData(items: items)) { _, _, items in
                            self?.didSelect(items: items, draftItem: [], clickType: 2)
                        }
                        let item = items.first!
                        var size = CGSize()
                        switch item {
                        case .photo(let photo):
                            if items.count > 1 {
                                size = self!.calculateSize(width: photo.asset!.pixelWidth, height: photo.asset!.pixelHeight)
                            }else{
                                let sideMargin: CGFloat = 24
                                let overlapppingNextPhoto: CGFloat = 37
                                let screenWidth = YPImagePickerConfiguration.screenWidth
                                let s = screenWidth - (sideMargin + overlapppingNextPhoto)
                                size = self!.calculateSingleImageSize(image: photo.image, size: s)
                            }
                          
                        case .video(_):break
                        }
                        selectionsGalleryVC.cropWidth = size.width
                        selectionsGalleryVC.cropHeight = size.height
                        self?.pushViewController(selectionsGalleryVC, animated: true)
                        return
                    }
                    
                }
            }
            
            // One item flow
            let item = items.first!
            switch item {
            case .photo(let photo):
                let completion = { (photo: YPMediaPhoto) in
                    let mediaItem = YPMediaItem.photo(p: photo)
                    // Save new image or existing but modified, to the photo album.
                    if YPConfig.shouldSaveNewPicturesToAlbum {
                        let isModified = photo.modifiedImage != nil
                        if photo.fromCamera || (!photo.fromCamera && isModified) {
                            YPPhotoSaver.trySaveImage(photo.image, inAlbumNamed: YPConfig.albumName)
                        }
                    }
                    self?.didSelect(items: [mediaItem], draftItem: [], clickType: 0)
                }
                
                func showCropVC(photo: YPMediaPhoto, completion: @escaping (_ aphoto: YPMediaPhoto) -> Void) {
                    if case let YPCropType.rectangle(ratio) = YPConfig.showsCrop {
                        let cropVC = YPCropVC(image: photo.image, ratio: ratio)
                        cropVC.didFinishCropping = { croppedImage in
                            photo.modifiedImage = croppedImage
                            completion(photo)
                        }
                        self?.pushViewController(cropVC, animated: true)
                    } else {
                        completion(photo)
                    }
                }
                
                if YPConfig.showsPhotoFilters {
                    let filterVC = YPPhotoFiltersVC(inputPhoto: photo,
                                                    isFromSelectionVC: false)
                    // Show filters and then crop
                    filterVC.didSave = { outputMedia in
                        if case let YPMediaItem.photo(outputPhoto) = outputMedia {
                            showCropVC(photo: outputPhoto, completion: completion)
                        }
                    }
                    self?.pushViewController(filterVC, animated: false)
                } else {
                    showCropVC(photo: photo, completion: completion)
                }
            case .video(let video):
                if YPConfig.showsVideoTrimmer {
                    let videoFiltersVC = YPVideoFiltersVC.initWith(video: video,
                                                                   isFromSelectionVC: false)
                    videoFiltersVC.didSave = { [weak self] outputMedia in
                        self?.didSelect(items: [outputMedia], draftItem: [], clickType: 0)
                    }
                    self?.pushViewController(videoFiltersVC, animated: true)
                } else {
                    self?.didSelect(items: [YPMediaItem.video(v: video)], draftItem: [], clickType: 0)
                }
            }
        }
    }
    
    deinit {
        print("Picker deinited 👍")
    }
    
    private func arrangeArtworkData(items:[YPMediaItem]) -> [YPMediaItem]{
        var artworkArray : [YPMediaItem] = []
        YPPhotoSaver.clearAllFile()
        for (position,item) in items.enumerated(){
            switch item {
            case .photo(let photo):
                let currentTimeStamp = NSDate().timeIntervalSince1970.toInt()
                let imageName = "\(position)image\(currentTimeStamp).jpg"
               if let imagePath = saveImage(image: photo.image, imageName: imageName)
               {
                let artwork = YPMediaPhoto(image: photo.image, exifMeta: nil, fromCamera: photo.fromCamera, asset: photo.asset, url: imagePath, widthRatio: YPLibraryVC().targetWidth, heightRatio: YPLibraryVC().targetHeight, imageName: imageName)
                let artworkMedia = YPMediaItem.photo(p: artwork)
                artworkArray.append(artworkMedia)
               }
            case .video(v:):break
            }
        }
        return artworkArray
    }
    
    private func saveImage(image:UIImage,imageName:String) -> URL?{
        if let imagePath = YPPhotoSaver.saveImageToDirectory(imageName: imageName, image: image, folderName: YPConfig.albumName)
      {
        return imagePath
      }else{
        return nil
      }
    }
    
    private func setupLoadingView() {
        view.sv(
            loadingView
        )
        loadingView.fillContainer()
        loadingView.alpha = 0
    }
    
    func calculateSize(width:Int,height:Int) -> CGSize{
            if width > height {
                let ratio = CGFloat(Double(height) / Double(width))
                let setLength = self.view.frame.width - 50.0
                    let setHeight = setLength * ratio
                    return CGSize(width: setLength, height: setHeight)
            } else {
                let ratio = CGFloat(Double(height) / Double(width))
                let setLength = self.view.frame.width - 100.0
                let setHeight = setLength * ratio
                return CGSize(width: setLength, height: setHeight)
            }
    }
    func calculateSingleImageSize(image:UIImage,size:CGFloat) -> CGSize{
        var width : CGFloat = 0.0
        var height : CGFloat  = 0.0
        if image.size.width > image.size.height{
             width = size
             height = size
        }else if image.size.width < image.size.height{
             width = size
            height = size - 24
        }else{
            width = size
            height = size
        }
        return CGSize(width: width, height: height)
    }
}

extension YPImagePicker: ImagePickerDelegate {
    
    func noPhotos() {
        self.imagePickerDelegate?.noPhotos()
    }
    

    func shouldAddToSelection(indexPath: IndexPath, numSelections: Int) -> Bool {
        return self.imagePickerDelegate?.shouldAddToSelection(indexPath: indexPath, numSelections: numSelections)
            ?? true
    }
}
extension UIImage {
    var jpeg: Data? { jpegData(compressionQuality: 0) }  // QUALITY min = 0 / max = 1
    var png: Data? { pngData() }
}
extension Data {
    var uiImage: UIImage? { UIImage(data: self) }
}
extension Double {
    func format(f: String) -> String {
        return NSString(format: "%\(f)f" as NSString, self) as String
    }

    func toString() -> String {
        return String(format: "%.1f",self)
    }

    func toInt() -> Int{
        var temp:Int64 = Int64(self)
        return Int(temp)
    }
}
