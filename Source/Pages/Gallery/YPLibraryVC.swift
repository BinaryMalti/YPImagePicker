//
//  YPLibraryVC.swift
//  YPImagePicker
//
//  Created by Sacha Durand Saint Omer on 27/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import Photos
import UIKit

protocol YPLibraryDelegate: AnyObject {
    func showCroppedImage(rect: CGRect, image: UIImage)
}

public class YPLibraryVC: UIViewController, YPPermissionCheckable, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    internal weak var delegate: YPLibraryViewDelegate?
    internal var v: YPLibraryView!
    internal var isProcessing = false // true if video or image is in processing state
    internal var multipleSelectionEnabled = false
    internal var initialized = false
    internal var selection = [YPLibrarySelection]()
    internal var currentlySelectedIndex: Int = 0
    internal let mediaManager = LibraryMediaManager()
    internal var latestImageTapped = ""
    internal let panGestureHelper = PanGestureHelper()
    internal var fromCamera = false
    internal var fromCropClick = false
    var targetWidth: CGFloat = 0.0
    var targetHeight: CGFloat = 0.0
    private var cameraPicker: UIImagePickerController
    public var didCapturePhoto: ((YPMediaItem) -> Void)?
    var singleImage: UIImage?
    var selectedDraftItem: DraftItems?
    
    // MARK: - Init

    public required init(items: [YPMediaItem]?) {
        self.cameraPicker = UIImagePickerController()
        self.singleImage = nil
        super.init(nibName: nil, bundle: nil)
        title = YPConfig.wordings.libraryTitle
        view.backgroundColor = UIColor.white
        if let firstItem = items?.first {
            switch firstItem {
            case .photo(let photo):
                singleImage = photo.image
            case .video(v: _):
                // not using
                break
            }
        }
        if YPConfig.showDrafts {
            v.cropImageButton.isHidden = true
            v.cameraButton.isHidden = true
            v.assetZoomableView.photoImageView.image = YPConfig.draftImages[0].image
            self.v.postTypeDropDownTextField.text = YPConfig.dropdownArray[1]
            if YPConfig.dropdownArray[1] == "Draft" {
                isFirstItemSelectedMultipleSelection = true
                if YPConfig.draftImages.count > 0 {
                    picker.selectRow(1, inComponent: 0, animated: true)
                    pickerView(picker, didSelectRow: 1, inComponent: 0)
                } else {
                    delegate?.noPhotosForOptions()
                }
            }
            
        } else {
            checkPermission()
        }
        v.zoomableWidthConstraint = v.assetZoomableView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width)
        v.zoomableHeightConstraint = v.assetZoomableView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.width)
        v.zoomableWidthConstraint?.isActive = true
        v.zoomableHeightConstraint?.isActive = true
    }
    
    public convenience init() {
        self.init(items: nil)
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isImageCropped = false
    var croppedimage: UIImage?
    func updateImageCrop(cropRect: CGRect, image: UIImage) {
        let asset = mediaManager.fetchResult[currentlySelectedIndex]
        selection = [
            YPLibrarySelection(index: currentlySelectedIndex,
                               cropRect: cropRect,
                               scrollViewContentOffset: v.assetZoomableView!.contentOffset,
                               scrollViewZoomScale: v.assetZoomableView!.zoomScale,
                               assetIdentifier: asset.localIdentifier,
                               croppedImage: image)
        ]
        isImageCropped = true
        isFirstItemSelectedMultipleSelection = true
        croppedimage = image
        changeAsset(asset, cropImage: image)
    }
    
    func setAlbum(_ album: YPAlbum) {
        title = album.title
        mediaManager.collection = album.collection
        currentlySelectedIndex = 0
        if !multipleSelectionEnabled {
            selection.removeAll()
        }
        refreshMediaRequest()
    }

    public func selectDraftMedia() -> DraftItems? {
        return selectedDraftItem
    }
    
    func initialize() {
        mediaManager.initialize()
        mediaManager.v = v
        setupCollectionView()
        registerForLibraryChanges()
        panGestureHelper.registerForPanGesture(on: v)
        registerForTapOnPreview()
        refreshMediaRequest()
        v.assetViewContainer.multipleSelectionButton.isHidden = !(YPConfig.library.maxNumberOfItems > 1)
        v.assetViewContainer.squareCropButton.isHidden = true
        v.assetViewContainer.multipleSelectionButton.isHidden = true
        createPostTypeDropDown()
        v.maxNumberWarningLabel.text = String(format: YPConfig.wordings.warningMaxItemsLimit,
                                              YPConfig.library.maxNumberOfItems)
        if YPConfig.library.defaultMultipleSelection || selection.count > 1 {
            showMultipleSelection()
        }
        
        if let preselectedItems = YPConfig.library.preselectedItems, !preselectedItems.isEmpty {
            selection = preselectedItems.compactMap { item -> YPLibrarySelection? in
                var itemAsset: PHAsset?
                switch item {
                case .photo(let photo):
                    if photo.asset == nil {
                        itemAsset = mediaManager.fetchResult[0]
                    } else {
                        itemAsset = photo.asset
                    }
                    singleImage = photo.image
                case .video(let video):
                    itemAsset = video.asset
                }
                guard let asset = itemAsset else {
                    return nil
                }
                
                // The negative index will be corrected in the collectionView:cellForItemAt:
                return YPLibrarySelection(index: -1, assetIdentifier: asset.localIdentifier)
            }
            v.assetViewContainer.setMultipleSelectionMode(on: multipleSelectionEnabled)
            v.collectionView.reloadData()
        }
        if v.showDraftImages || YPConfig.showDrafts {
            self.multipleSelectionEnabled = false
        }
        guard mediaManager.hasResultItems else {
            return
        }
    }
    
    // TGP - Post Type DropDown
    let picker = UIPickerView()
    func createPostTypeDropDown() {
        v.postTypeDropDownTextField.tintColor = UIColor.clear
        picker.dataSource = self
        picker.delegate = self
        v.postTypeDropDownTextField.inputView = picker
    }
    
    // MARK: - View Lifecycle
    
    override public func loadView() {
        v = YPLibraryView.xibView()
        view = v
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        // When crop area changes in multiple selection mode,
        // we need to update the scrollView values in order to restore
        // them when user selects a previously selected item.
        v.assetZoomableView.cropAreaDidChange = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateCropInfo()
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        v.postTypeDropDownTextField.font = YPConfig.fonts.pickerTitleFont
        v.cropImageButton.addTarget(self,
                                    action: #selector(cropButtonTapped),
                                    for: .touchUpInside)
        v.multiselectImageButton.addTarget(self,
                                           action: #selector(multipleSelectionButtonTapped),
                                           for: .touchUpInside)
        v.assetViewContainer.squareCropButton
            .addTarget(self,
                       action: #selector(squareCropButtonTapped),
                       for: .touchUpInside)
        v.assetViewContainer.multipleSelectionButton
            .addTarget(self,
                       action: #selector(multipleSelectionButtonTapped),
                       for: .touchUpInside)
        v.cameraButton.addTarget(self,
                                 action: #selector(openCameraButtonTapped),
                                 for: .touchUpInside)
        // Forces assetZoomableView to have a contentSize.
        // otherwise 0 in first selection triggering the bug : "invalid image size 0x0"
        // Also fits the first element to the square if the onlySquareFromLibrary = true
        if !YPConfig.library.onlySquare, v.assetZoomableView.contentSize == CGSize(width: 0, height: 0) {
            v.assetZoomableView.setZoomScale(1, animated: false)
        }
        
        // Activate multiple selection when using `minNumberOfItems`
        if YPConfig.library.minNumberOfItems > 1 {
            multipleSelectionButtonTapped()
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        pausePlayer()
        NotificationCenter.default.removeObserver(self)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    @objc
    func showPickerView() {
        v.dropdownPickerView.delegate = self
        v.dropdownPickerView.dataSource = self
        v.dropdownPickerView.backgroundColor = .white
        v.dropdownPickerView.isHidden = false
    }
    
    func cropVisiblePortionOf(imageView: UIImageView, width: CGFloat, height: CGFloat) -> UIImage? {
        let zoomScaleX = imageView.frame.size.width / width
        let zoomScaleY = imageView.frame.size.height / height
        let zoomedSize = CGSize(width: width * zoomScaleX, height: height * zoomScaleY)
        
        UIGraphicsBeginImageContext(zoomedSize)
        imageView.image?.draw(in: CGRect(x: 0, y: 0, width: zoomedSize.width, height: zoomedSize.height))
        let zoomedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        zoomedImage?.draw(at: CGPoint(x: imageView.frame.origin.x, y: imageView.frame.origin.y))
        let cropedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return cropedImage
    }
    
    // MARK: - Crop control
    
    @objc
    func squareCropButtonTapped() {
        doAfterPermissionCheck { [weak self] in
            self?.v.assetViewContainer.squareCropButtonTapped()
        }
    }
    
    @objc
    func cropButtonTapped() {
        doAfterPermissionCheck { [weak self] in
            if let image = self?.singleImage {
                self?.fromCamera = false
                self?.fromCropClick = true
                self?.isImageCropped = false
                let imageItem = YPMediaItem.photo(p: YPMediaPhoto(image: image))
                self?.didCapturePhoto?(imageItem)
                //                let cropVC = CustomCropViewController(item:image)
                //                self?.present(cropVC, animated: true)
            }
        }
    }
    
    // MARK: - Multiple Selection
    
    @objc
    func multipleSelectionButtonTapped() {
        isFirstItemSelectedMultipleSelection = true
        doAfterPermissionCheck { [weak self] in
            if let self = self {
                if !self.multipleSelectionEnabled {
                    // TGP -reset preview scrollview(AssetZoomableView) if multiple selection disabled
//                    let defaultAssetZoomableViewSize = UIScreen.main.bounds.width
//                    self.v.zoomableHeightConstraint?.constant = defaultAssetZoomableViewSize
//                    self.v.zoomableWidthConstraint?.constant = defaultAssetZoomableViewSize
                    self.selection.removeAll()
                }
                self.showMultipleSelection()
            }
        }
    }
    
    @objc
    func openCameraButtonTapped() {
        doAfterPermissionCheck { [weak self] in
            if self != nil {
                let sourceType = UIImagePickerController.SourceType.camera
                if UIImagePickerController.isSourceTypeAvailable(
                    UIImagePickerController.SourceType.camera)
                {
                    self!.cameraPicker.sourceType = sourceType
                    self!.cameraPicker.delegate = self
                    self!.cameraPicker.modalPresentationStyle = .fullScreen
                    self?.present(self!.cameraPicker, animated: false)
                }
            }
        }
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let pickedImage = info[.originalImage] as? UIImage {
            self.fromCamera = true
            self.fromCropClick = false
            let cropVC = CustomCropViewController(item: pickedImage)
            cropVC.fromCamera = true
            cropVC.didFinishCropping = { croppedImage in
                self.showArtworks(imageCrop: croppedImage)
            }
            self.navigationController?.pushViewController(cropVC, animated: true)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    internal var isSaveAsDraft = false
    func showArtworks(imageCrop: UIImage) {
        YPPhotoSaver.clearAllFile()
        var artworkSetArray: [YPMediaItem] = []
        let currentTimeStamp = NSDate().timeIntervalSince1970.toInt()
        let imageName = "0image\(currentTimeStamp).jpg"
        let ypImage = YPMediaPhoto(image: imageCrop,
                                   exifMeta: nil,
                                   fromCamera: true,
                                   asset: nil,
                                   url: nil,
                                   widthRatio: nil,
                                   heightRatio: nil,
                                   imageName: imageName)
        artworkSetArray.append(YPMediaItem.photo(p: ypImage))
        if artworkSetArray.count > 0 {
            self.didCapturePhoto?(artworkSetArray.first!)
        } else {
            print("No items selected yet.")
        }
    }
    
    func showMultipleSelection() {
        // Prevent desactivating multiple selection when using `minNumberOfItems`
        if YPConfig.library.minNumberOfItems > 1, multipleSelectionEnabled {
            return
        }
        
        multipleSelectionEnabled = !multipleSelectionEnabled
        croppedimage = nil
        if multipleSelectionEnabled {
            if selection.isEmpty, YPConfig.library.preSelectItemOnMultipleSelection,
               delegate?.libraryViewShouldAddToSelection(indexPath: IndexPath(row: currentlySelectedIndex, section: 0),
                                                         numSelections: selection.count) ?? true
            {
                self.v.assetZoomableView.fitImage(false)
                let asset = mediaManager.fetchResult[currentlySelectedIndex]
                if isImageCropped {
                    selection = [
                        YPLibrarySelection(index: currentlySelectedIndex,
                                           cropRect: v.currentCropRect(),
                                           scrollViewContentOffset: v.assetZoomableView!.contentOffset,
                                           scrollViewZoomScale: v.assetZoomableView!.zoomScale,
                                           assetIdentifier: asset.localIdentifier,
                                           croppedImage: croppedimage)
                    ]
                } else {
                    selection = [
                        YPLibrarySelection(index: currentlySelectedIndex,
                                           cropRect: v.currentCropRect(),
                                           scrollViewContentOffset: v.assetZoomableView!.contentOffset,
                                           scrollViewZoomScale: v.assetZoomableView!.zoomScale,
                                           assetIdentifier: asset.localIdentifier)
                    ]
                }
                v.multiselectCountLabel.text = String(format: "%02d", selection.count)
            }
        } else {
            // TGP -reset preview scrollview(AssetZoomableView) if multiple selection disabled
            let defaultAssetZoomableViewSize = self.v.assetViewContainer.frame.width
            self.v.zoomableHeightConstraint?.constant = defaultAssetZoomableViewSize
            self.v.zoomableWidthConstraint?.constant = defaultAssetZoomableViewSize
           // self.v.assetZoomableView.centerAssetView()
            self.v.assetZoomableView.fitImage(false)
            self.isFirstItemSelectedMultipleSelection = true
            selection.removeAll()
            if !YPConfig.showDrafts {
                self.v.cropImageButton.isHidden = false
                self.v.cameraButton.isHidden = false
            }
            addToSelection(indexPath: IndexPath(row: currentlySelectedIndex, section: 0))
            self.v.multiselectCountLabel.text = ""
        }
        
        v.assetViewContainer.setMultipleSelectionMode(on: multipleSelectionEnabled)
        v.toggleMultiselectButton(isOn: multipleSelectionEnabled)
        v.collectionView.reloadData()
        checkLimit()
        delegate?.libraryViewDidToggleMultipleSelection(enabled: false)
    }
    
    // MARK: - Tap Preview
    
    func registerForTapOnPreview() {
        let tapImageGesture = UITapGestureRecognizer(target: self, action: #selector(tappedImage))
        v.assetViewContainer.addGestureRecognizer(tapImageGesture)
    }
    
    @objc
    func tappedImage() {
        if !panGestureHelper.isImageShown {
            panGestureHelper.resetToOriginalState()
            // no dragup? needed? dragDirection = .up
            v.refreshImageCurtainAlpha()
        }
    }
    
    // MARK: - Permissions
    
    func doAfterPermissionCheck(block: @escaping () -> Void) {
        checkPermissionToAccessPhotoLibrary { hasPermission in
            if hasPermission {
                block()
            }
        }
    }
    
    func checkPermission() {
        checkPermissionToAccessPhotoLibrary { [weak self] hasPermission in
            guard let strongSelf = self else {
                return
            }
            if hasPermission, !strongSelf.initialized {
                strongSelf.initialize()
                strongSelf.initialized = true
            }
        }
    }
    
    // Async beacause will prompt permission if .notDetermined
    // and ask custom popup if denied.
    func checkPermissionToAccessPhotoLibrary(block: @escaping (Bool) -> Void) {
        // Only intilialize picker if photo permission is Allowed by user.
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            block(true)
        #if compiler(>=5.3)
        case .limited:
            block(true)
        #endif
        case .restricted, .denied:
            let popup = YPPermissionDeniedPopup()
            let alert = popup.popup(cancelBlock: {
                block(false)
            })
            present(alert, animated: true, completion: nil)
        case .notDetermined:
            // Show permission popup and get new status
            PHPhotoLibrary.requestAuthorization { s in
                DispatchQueue.main.async {
                    block(s == .authorized)
                }
            }
        @unknown default:
            fatalError()
        }
    }
    
    func refreshMediaRequest() {
        let options = buildPHFetchOptions()
        if let collection = mediaManager.collection {
            mediaManager.fetchResult = PHAsset.fetchAssets(in: collection, options: options)
        } else {
            mediaManager.fetchResult = PHAsset.fetchAssets(with: options)
        }
        
        if mediaManager.hasResultItems {
            changeAsset(mediaManager.fetchResult[0])
            v.collectionView.reloadData()
            v.collectionView.selectItem(at: IndexPath(row: 0, section: 0),
                                        animated: false,
                                        scrollPosition: UICollectionView.ScrollPosition())
            if !multipleSelectionEnabled, YPConfig.library.preSelectItemOnMultipleSelection {
                addToSelection(indexPath: IndexPath(row: 0, section: 0))
            }
        } else {
            delegate?.noPhotosForOptions()
        }
        scrollToTop()
    }
    
    func buildPHFetchOptions() -> PHFetchOptions {
        // Sorting condition
        if let userOpt = YPConfig.library.options {
            return userOpt
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = YPConfig.library.mediaType.predicate()
        return options
    }
    
    func scrollToTop() {
        tappedImage()
        v.collectionView.contentOffset = CGPoint.zero
    }
    
    // MARK: - ScrollViewDelegate
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == v.collectionView {
            if !v.showDraftImages {
                mediaManager.updateCachedAssets(in: self.v.collectionView)
            }
        }
    }
    
    var isFirstItemSelectedMultipleSelection = true
    var isImageAlreadySelected = false
    // var contentSize : CGSize = CGSize(width: 0, height: 0)
    
    func changeAsset(_ asset: PHAsset, cropImage: UIImage? = nil) {
        latestImageTapped = asset.localIdentifier
        delegate?.libraryViewStartedLoadingImage()
        let completion = { (isLowResIntermediaryImage: Bool) in
            self.v.hideOverlayView()
            self.v.assetViewContainer.refreshSquareCropButton()
            self.singleImage = self.v.assetZoomableView.assetImageView.image
            if self.multipleSelectionEnabled {
                if self.isFirstItemSelectedMultipleSelection { // TGP - Firt image in multiple selection is selected. isFirstItem is used to get the height and width of hero image and adjust other selected images as per hero image height-width
                    self.isImageAlreadySelected = true
                    self.isFirstItemSelectedMultipleSelection = false
                    self.v.assetZoomableView.fitImage(false)
                    let height = self.v.assetZoomableView.assetImageView.frame.height
                    let width = self.v.assetZoomableView.assetImageView.frame.width
                    let assetZoomableViewHeight = self.v.assetZoomableView.frame.height
                    if height > width {
                        self.v.zoomableWidthConstraint?.constant = width
                        self.v.zoomableHeightConstraint?.constant = assetZoomableViewHeight
                    } else {
                        self.v.zoomableWidthConstraint?.constant = width
                        self.v.zoomableHeightConstraint?.constant = height
                    }
                } else {
                    if self.selection.count > 1 {
                        self.v.assetZoomableView.fitImage(true)
                        self.v.assetZoomableView.layoutSubviews()
                        self.v.assetZoomableView.isMultipleSelectionEnabled = true
                    }
                    // else{
                    //                        if !self.calledOnce{
                    //                        self.v.assetZoomableView.fitImage(false)
                    //                        self.v.assetZoomableView.layoutSubviews()
                    //                        }else{
                    // self.v.assetZoomableView.fitImage(false)
                    // self.v.assetZoomableView.layoutSubviews()
                    //    }
                    //   }
                }
            } else {
                // TGP -reset preview scrollview(AssetZoomableView) if multiple selection disabled
                let defaultAssetZoomableViewSize = UIScreen.main.bounds.width
                self.v.zoomableHeightConstraint?.constant = defaultAssetZoomableViewSize
                self.v.zoomableWidthConstraint?.constant = defaultAssetZoomableViewSize
                self.v.assetZoomableView.fitImage(false)
                self.v.assetZoomableView.layoutSubviews()
            }
            
            self.updateCropInfo()
            if !isLowResIntermediaryImage {
                self.v.hideLoader()
                self.delegate?.libraryViewFinishedLoading()
            }
        }
        
        let updateCropInfo = {
            self.updateCropInfo()
        }
        
        // MARK: add a func(updateCropInfo) after crop multiple

        DispatchQueue.global(qos: .userInitiated).async {
            switch asset.mediaType {
            case .image:
                if cropImage != nil {
                    DispatchQueue.main.async {
                        self.v.assetZoomableView.setDraftImage(cropImage!, completion: completion, updateCropInfo: updateCropInfo)
                    }
                } else {
                    self.v.assetZoomableView.setImage(asset,
                                                      mediaManager: self.mediaManager,
                                                      storedCropPosition: self.fetchStoredCrop(),
                                                      completion: completion,
                                                      updateCropInfo: updateCropInfo)
                }
            case .video:
                self.v.assetZoomableView.setVideo(asset,
                                                  mediaManager: self.mediaManager,
                                                  storedCropPosition: self.fetchStoredCrop(),
                                                  completion: { completion(false) },
                                                  updateCropInfo: updateCropInfo)
            case .audio, .unknown:
                ()
            @unknown default:
                fatalError()
            }
        }
    }
    
    func calculateSingleImageSize(imageWidth: CGFloat, imageHeight: CGFloat, size: CGFloat) -> CGSize {
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0
        if imageWidth < imageHeight {
            let requireHeight = view.frame.height / 2.0
            let requireWidth = (requireHeight * imageWidth) / imageHeight
            let ratio = imageWidth / imageHeight
            if ratio < 0.8 {
                width = requireWidth
                height = CGFloat(requireHeight)
            } else {
                width = requireWidth
                height = CGFloat(requireHeight)
            }
        } else if imageWidth > imageHeight {
            let requireWidth = size - 75.0
            let requireHeight = (requireWidth * imageHeight) / imageWidth
            width = CGFloat(requireWidth)
            height = requireHeight
        } else {
            width = size
            height = size
        }
        return CGSize(width: width, height: height)
    }
    
    func changeAssetDraft(_ asset: UIImage) {
        // latestImageTapped = asset.localIdentifier
        delegate?.libraryViewStartedLoadingImage()
        let completion = { (isLowResIntermediaryImage: Bool) in
            self.v.hideOverlayView()
            DispatchQueue.main.async {
                self.v.assetViewContainer.refreshSquareCropButton()
            }
            self.singleImage = self.v.assetZoomableView.assetImageView.image
            if self.multipleSelectionEnabled {
                if self.isFirstItemSelectedMultipleSelection {
                    self.isFirstItemSelectedMultipleSelection = false
                    //                self.v.leftMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.x
                    //                self.v.rightMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.x
                    //                self.v.bottomMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.y
                    //                self.v.topMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.y
                    let targetSize = self.calculateSingleImageSize(imageWidth: self.v.assetZoomableView.assetImageView.frame.width, imageHeight: self.v.assetZoomableView.assetImageView.frame.height, size: self.v.assetZoomableView.assetImageView.frame.width)
                    self.targetWidth = targetSize.width
                    self.targetHeight = targetSize.height
                    //                    if (self.v.assetZoomableView.assetImageView.frame.width < self.v.assetZoomableView.assetImageView.frame.height)
                    //                    {
                    //                        let ratio = self.v.assetZoomableView.assetImageView.frame.width / self.v.assetZoomableView.assetImageView.frame.height
                    //                        if ratio < 0.8 {
                    //                            self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                    //                            self.targetHeight = self.v.assetZoomableView.assetImageView.frame.width * 1.25
                    //                        }else{
                    //                            self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                    //                            self.targetHeight = self.v.assetZoomableView.assetImageView.frame.width * ratio
                    //                        }
                    //                    }else if  (self.v.assetZoomableView.assetImageView.frame.width > self.v.assetZoomableView.assetImageView.frame.height){
                    //                        self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                    //                        self.targetHeight = self.v.assetZoomableView.assetImageView.frame.height
                    //                    }else{
                    //                        self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                    //                        self.targetHeight = self.v.assetZoomableView.assetImageView.frame.height
                    //                    }
                    
                    self.view.setNeedsLayout()
                } else {
                    if self.selection.count > 1 {
                        self.v.assetZoomableView.fitImage(true)
                        self.v.assetZoomableView.layoutSubviews()
                    }
                }
            } else {
                //                        self.v.leftMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.x
                //                        self.v.rightMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.x
                //                        self.v.bottomMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.y
                //                        self.v.topMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.y
                self.targetWidth = self.v.assetZoomableView.photoImageView.frame.width
                self.targetHeight = self.v.assetZoomableView.photoImageView.frame.height
                self.view.setNeedsLayout()
            }
            
            self.updateCropInfo()
            if !isLowResIntermediaryImage {
                self.v.hideLoader()
                self.delegate?.libraryViewFinishedLoading()
            }
        }
        
        let updateCropInfo = {
            self.updateCropInfo()
        }
        
        // MARK: add a func(updateCropInfo) after crop multiple

        DispatchQueue.main.async {
            self.v.assetZoomableView.setDraftImage(asset,
                                                   completion: completion,
                                                   updateCropInfo: updateCropInfo)
        }
    }
    
    // MARK: - Verification
    
    private func fitsVideoLengthLimits(asset: PHAsset) -> Bool {
        guard asset.mediaType == .video else {
            return true
        }
        
        let tooLong = floor(asset.duration) > YPConfig.video.libraryTimeLimit
        let tooShort = floor(asset.duration) < YPConfig.video.minimumTimeLimit
        
        if tooLong || tooShort {
            DispatchQueue.main.async {
                let alert = tooLong ? YPAlert.videoTooLongAlert(self.view) : YPAlert.videoTooShortAlert(self.view)
                self.present(alert, animated: true, completion: nil)
            }
            return false
        }
        
        return true
    }
    
    // MARK: - Stored Crop Position
    
    internal func updateCropInfo(shouldUpdateOnlyIfNil: Bool = false) {
        guard let selectedAssetIndex = selection.firstIndex(where: { $0.index == currentlySelectedIndex }) else {
            return
        }
        
        if shouldUpdateOnlyIfNil, selection[selectedAssetIndex].scrollViewContentOffset != nil {
            return
        }
        
        // Fill new values
        var selectedAsset = selection[selectedAssetIndex]
        selectedAsset.scrollViewContentOffset = v.assetZoomableView.contentOffset
        selectedAsset.scrollViewZoomScale = v.assetZoomableView.zoomScale
        //        selectedAsset.cutWidth = v.leftMaskHeight.constant
        //        selectedAsset.cutHeight = v.topMaskHeight.constant
        if multipleSelectionEnabled {
            if isImageCropped, selectedAssetIndex == 0 {
                selectedAsset.cropRect = selection[selectedAssetIndex].cropRect
            } else {
                selectedAsset.cropRect = v.currentCropRect()
            }
        } else {
            selectedAsset.cropRect = v.currentCropRect()
        }
        // Replace
        selection.remove(at: selectedAssetIndex)
        selection.insert(selectedAsset, at: selectedAssetIndex)
    }
    
    // TGP
    private func multiSelectionCount() {
        if !YPConfig.showDrafts || !v.showDraftImages {
            DispatchQueue.main.async {
                if self.multipleSelectionEnabled {
                    if self.selection.count > 1 {
                        self.v.cropImageButton.isHidden = true
                        self.v.cameraButton.isHidden = true
                        self.v.multiselectCountLabel.text = String(format: "%02d", self.selection.count)
                    } else {
                        self.v.cropImageButton.isHidden = false
                        self.v.cameraButton.isHidden = false
                        self.v.multiselectCountLabel.text = String(format: "%02d", 1)
                    }
                } else {
                    self.v.cropImageButton.isHidden = false
                    self.v.cameraButton.isHidden = false
                }
            }
        }
    }
    
    internal func fetchStoredCrop() -> YPLibrarySelection? {
        multiSelectionCount()
        if self.multipleSelectionEnabled,
           self.selection.contains(where: { $0.index == self.currentlySelectedIndex })
        {
            guard let selectedAssetIndex = self.selection
                .firstIndex(where: { $0.index == self.currentlySelectedIndex })
            else {
                return nil
            }
            return self.selection[selectedAssetIndex]
        }
        return nil
    }
    
    internal func hasStoredCrop(index: Int) -> Bool {
        return self.selection.contains(where: { $0.index == index })
    }
    
    // MARK: - Fetching Media
    
    private func fetchImageAndCrop(for asset: PHAsset,
                                   withCropRect: CGRect? = nil,
                                   callback: @escaping (_ photo: UIImage, _ exif: [String: Any]) -> Void)
    {
        delegate?.libraryViewDidTapNext()
        let cropRect = withCropRect ?? DispatchQueue.main.sync { v.currentCropRect() }
        let ts = targetSize(for: asset, cropRect: cropRect)
        self.targetWidth = ts.width
        self.targetHeight = ts.height
        mediaManager.imageManager?.fetchImage(for: asset, cropRect: cropRect, targetSize: ts, callback: callback)
    }
    
    private func fetchVideoAndCropWithDuration(for asset: PHAsset,
                                               withCropRect rect: CGRect,
                                               duration: Double,
                                               callback: @escaping (_ videoURL: URL?) -> Void)
    {
        delegate?.libraryViewDidTapNext()
        let timeDuration = CMTimeMakeWithSeconds(duration, preferredTimescale: 1000)
        mediaManager.fetchVideoUrlAndCropWithDuration(for: asset,
                                                      cropRect: rect,
                                                      duration: timeDuration,
                                                      callback: callback)
    }
    
    public func selectedMedia(photoCallback: @escaping (_ photo: YPMediaPhoto) -> Void,
                              videoCallback: @escaping (_ videoURL: YPMediaVideo) -> Void,
                              multipleItemsCallback: @escaping (_ items: [YPMediaItem]) -> Void)
    {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.croppedimage != nil {
                let selectedAssets: [(asset: UIImage, cropRect: CGRect?)] = self.selection.map {
                    if $0.croppedImage != nil {
                        return ($0.croppedImage!, $0.cropRect)
                    } else {
                        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [$0.assetIdentifier!],
                                                              options: PHFetchOptions()).firstObject else { fatalError() }
                        var photo: YPMediaPhoto?
                        self.fetchImageAndCrop(for: asset, withCropRect: $0.cropRect) { image, exifMeta in
                            photo = YPMediaPhoto(image: image.resizedImageIfNeeded(),
                                                 exifMeta: exifMeta, asset: asset)
                        }
                        return (photo!.image, $0.cropRect)
                    }
                }
                
                // Multiple selection
                if self.multipleSelectionEnabled, self.selection.count > 1 {
                    // Fill result media items array
                    var resultMediaItems: [YPMediaItem] = []
                    let asyncGroup = DispatchGroup()
                    for asset in selectedAssets {
                        asyncGroup.enter()
                        resultMediaItems.append(YPMediaItem.photo(p: YPMediaPhoto(image: asset.asset)))
                        asyncGroup.leave()
                    }
                    
                    asyncGroup.notify(queue: .main) {
                        // TODO: sort the array based on the initial order of the assets in selectedAssets
                        multipleItemsCallback(resultMediaItems)
                        self.delegate?.libraryViewFinishedLoading()
                    }
                } else {
                    if selectedAssets.count > 0 {
                        let item = selectedAssets.first!.asset
                        DispatchQueue.main.async {
                            self.delegate?.libraryViewFinishedLoading()
                            let photo = YPMediaPhoto(image: item.resizedImageIfNeeded())
                            photoCallback(photo)
                        }
                    }
                    return
                }
            } else {
                let selectedAssets: [(asset: PHAsset, cropRect: CGRect?)] = self.selection.map {
                    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [$0.assetIdentifier!],
                                                          options: PHFetchOptions()).firstObject else { fatalError() }
                    return (asset, $0.cropRect)
                }
                // Multiple selection
                if self.multipleSelectionEnabled, self.selection.count > 1 {
                    for asset in selectedAssets {
                        if self.fitsVideoLengthLimits(asset: asset.asset) == false {
                            return
                        }
                    }
                    // Fill result media items array
                    var resultMediaItems: [YPMediaItem] = []
                    let asyncGroup = DispatchGroup()
                    
                    var assetDictionary = [PHAsset?: Int]()
                    for (index, assetPair) in selectedAssets.enumerated() {
                        assetDictionary[assetPair.asset] = index
                    }
                    for asset in selectedAssets {
                        asyncGroup.enter()
                        switch asset.asset.mediaType {
                        case .image:
                            self.fetchImageAndCrop(for: asset.asset, withCropRect: asset.cropRect) { image, exifMeta in
                                let photo = YPMediaPhoto(image: image.resizedImageIfNeeded(),
                                                         exifMeta: exifMeta, asset: asset.asset)
                                resultMediaItems.append(YPMediaItem.photo(p: photo))
                                asyncGroup.leave()
                            }
                        case .video:
                            break
                        default:
                            break
                        }
                    }
                    
                    asyncGroup.notify(queue: .main) {
                        // TODO: sort the array based on the initial order of the assets in selectedAssets
                        resultMediaItems.sort { first, second -> Bool in
                            var firstAsset: PHAsset?
                            var secondAsset: PHAsset?
                            switch first {
                            case .photo(let photo):
                                firstAsset = photo.asset
                            case .video(let video):
                                firstAsset = video.asset
                            }
                            guard let firstIndex = assetDictionary[firstAsset] else {
                                return false
                            }
                            switch second {
                            case .photo(let photo):
                                secondAsset = photo.asset
                            case .video(let video):
                                secondAsset = video.asset
                            }
                            guard let secondIndex = assetDictionary[secondAsset] else {
                                return false
                            }
                            return firstIndex < secondIndex
                        }
                        multipleItemsCallback(resultMediaItems)
                        self.delegate?.libraryViewFinishedLoading()
                    }
                } else {
                    if selectedAssets.count > 0 {
                        let asset = selectedAssets.first!.asset
                        switch asset.mediaType {
                        case .audio, .unknown:
                            return
                        case .video:
                            break
                        case .image:
                            self.fetchImageAndCrop(for: asset) { image, exifMeta in
                                DispatchQueue.main.async {
                                    self.delegate?.libraryViewFinishedLoading()
                                    let photo = YPMediaPhoto(image: image.resizedImageIfNeeded(),
                                                             exifMeta: exifMeta,
                                                             asset: asset)
                                    photoCallback(photo)
                                }
                            }
                        @unknown default:
                            fatalError()
                        }
                    }
                    return
                }
            }
        }
    }
    
    // MARK: - TargetSize
    
    private func targetSize(for asset: PHAsset, cropRect: CGRect) -> CGSize {
        var width = (CGFloat(asset.pixelWidth) * cropRect.width).rounded(.toNearestOrEven)
        var height = (CGFloat(asset.pixelHeight) * cropRect.height).rounded(.toNearestOrEven)
        // round to lowest even number
        width = (width.truncatingRemainder(dividingBy: 2) == 0) ? width : width - 1
        height = (height.truncatingRemainder(dividingBy: 2) == 0) ? height : height - 1
        return CGSize(width: width, height: height)
    }
    
    // MARK: - Player
    
    func pausePlayer() {
        v.assetZoomableView.videoView.pause()
    }
    
    // MARK: - Deinit
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}
extension YPLibraryVC: UIPickerViewDelegate, UIPickerViewDataSource {
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return YPConfig.dropdownArray[row]
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return YPConfig.dropdownArray.count
    }

    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.v.postTypeDropDownTextField.font = YPConfig.fonts.pickerTitleFont
        self.v.postTypeDropDownTextField.text = YPConfig.dropdownArray[row]
        if YPConfig.dropdownArray[row] == "Draft" {
            // TO DO - TGP Memory Leakage issue & Smooth scrolling
            isFirstItemSelectedMultipleSelection = true
            if YPConfig.draftImages.count > 0 {
                multipleSelectionEnabled = false
                selectedDraftItem = YPConfig.draftImages[0]
                registerForTapOnPreview()
                loadDrafts(draftItem: YPConfig.draftImages, showDraft: true)
                scrollToTop()
            } else {
                let alert = UIAlertController(title: "No images available in drafts", message: "Draft gallery is empty.Add some artworks.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    alert.dismiss(animated: true, completion: nil)
                    self.view.endEditing(true)
                }))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            isFirstItemSelectedMultipleSelection = true
            var config = YPImagePickerConfiguration()
            config.showDrafts = false
            loadDrafts(draftItem: [], showDraft: false)
        }
        view.endEditing(true)
    }
}
