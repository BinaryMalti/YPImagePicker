//
//  YPLibraryVC.swift
//  YPImagePicker
//
//  Created by Sacha Durand Saint Omer on 27/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import UIKit
import Photos

protocol YPLibraryDelegate :AnyObject {
    func showCroppedImage(rect: CGRect)
}

public class YPLibraryVC: UIViewController, YPPermissionCheckable, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    

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
    var targetWidth : CGFloat = 0.0
    var targetHeight : CGFloat = 0.0
    private var cameraPicker: UIImagePickerController
    public var didCapturePhoto: ((UIImage) -> Void)?
    var singleImage : UIImage?
    var selectedDraftItem : DraftItems?
    
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
                //not using
                break
            }
        }
        if YPConfig.showDrafts{
            v.cropImageButton.isHidden = true
            v.clickImageButton.isHidden = true
            v.assetZoomableView.photoImageView.image = YPConfig.draftImages[0].image
                self.v.imageDropDownTextField.text = YPConfig.dropdownArray[1]
                if (YPConfig.dropdownArray[1] == "Draft"){
                    isFirstTime = true
                    if (YPConfig.draftImages.count > 0){
                        picker.selectRow(1, inComponent: 0, animated: true)
                        pickerView(picker, didSelectRow: 1, inComponent: 0)
                    }else{
                        delegate?.noPhotosForOptions()
                    }
                }
            
        }
    }
    
    public convenience init() {
        self.init(items: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateImageCrop(cropRect:CGRect){
       let asset = mediaManager.fetchResult[currentlySelectedIndex]
        selection = [
            YPLibrarySelection(index: currentlySelectedIndex,
                               cropRect: cropRect,
                               scrollViewContentOffset: v.assetZoomableView!.contentOffset,
                               scrollViewZoomScale: v.assetZoomableView!.zoomScale,
                               assetIdentifier: asset.localIdentifier,
                               cutWidth: v.leftMaskHeight.constant,
                               cutHeight: v.topMaskHeight.constant)
        ]
        updateCropInfo()
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
        createImagePicker()
        v.maxNumberWarningLabel.text = String(format: YPConfig.wordings.warningMaxItemsLimit,
                                              YPConfig.library.maxNumberOfItems)
        if let preselectedItems = YPConfig.library.preselectedItems, !preselectedItems.isEmpty {
            selection = preselectedItems.compactMap { item -> YPLibrarySelection? in
                var itemAsset: PHAsset?
                switch item {
                case .photo(let photo):
                    itemAsset = photo.asset
                    singleImage = photo.image
                case .video(let video):
                    itemAsset = video.asset
                }
                guard let asset = itemAsset else {
                    return nil
                }
                
                // The negative index will be corrected in the collectionView:cellForItemAt:
                return YPLibrarySelection(index: -1, assetIdentifier: asset.localIdentifier, cutWidth: v.leftMaskHeight.constant, cutHeight: v.topMaskHeight.constant)
                            }
            v.assetViewContainer.setMultipleSelectionMode(on: multipleSelectionEnabled)
            v.collectionView.reloadData()
        }
        guard mediaManager.hasResultItems else {
            return
        }
        if YPConfig.library.defaultMultipleSelection || selection.count > 1 {
            showMultipleSelection()
        }
        if v.showDraftImages || YPConfig.showDrafts{
            self.multipleSelectionEnabled = false
        }

    }
    
    let picker = UIPickerView()
    func createImagePicker() {
        v.imageDropDownTextField.tintColor = UIColor.clear
        picker.dataSource = self
        picker.delegate = self
        v.imageDropDownTextField.inputView = picker
    }
    
    // MARK: - View Lifecycle
    
    public override func loadView() {
        v = YPLibraryView.xibView()
        view = v
    }
    
    public override func viewDidLoad() {
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
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        v.clickImageButton.addTarget(self,
                                       action: #selector(openCameraButtonTapped),
                                       for: .touchUpInside)
        // Forces assetZoomableView to have a contentSize.
        // otherwise 0 in first selection triggering the bug : "invalid image size 0x0"
        // Also fits the first element to the square if the onlySquareFromLibrary = true
        if !YPConfig.library.onlySquare && v.assetZoomableView.contentSize == CGSize(width: 0, height: 0) {
            v.assetZoomableView.setZoomScale(1, animated: false)
        }
        
        // Activate multiple selection when using `minNumberOfItems`
        if YPConfig.library.minNumberOfItems > 1 {
            multipleSelectionButtonTapped()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        pausePlayer()
        NotificationCenter.default.removeObserver(self)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    
    @objc
    func showPickerView(){
        v.dropdownPickerView.delegate = self
        v.dropdownPickerView.dataSource = self
        v.dropdownPickerView.backgroundColor = .white
        v.dropdownPickerView.isHidden = false
    }

    
    func cropVisiblePortionOf(imageView: UIImageView,width:CGFloat,height:CGFloat) -> UIImage? {

        let zoomScaleX = (imageView.frame.size.width) / width
        let zoomScaleY = (imageView.frame.size.height) / height
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
            if let image = self?.singleImage{
                self?.fromCamera = false
                self?.fromCropClick = true
                self?.didCapturePhoto?(image)
//                let cropVC = CustomCropViewController(item:image)
//                self?.present(cropVC, animated: true)
            }
        }
    }
    
    // MARK: - Multiple Selection

    @objc
    func multipleSelectionButtonTapped() {
        isFirstTime = true
        doAfterPermissionCheck { [weak self] in
            if let self = self {
                if !self.multipleSelectionEnabled {
                    self.v.topMaskHeight.constant = 0
                    self.v.bottomMaskHeight.constant = 0
                    self.v.leftMaskHeight.constant = 0
                    self.v.rightMaskHeight.constant = 0
                    self.selection.removeAll()
                }else{
                }
                self.showMultipleSelection()
            }
        }
    }
    
    @objc
    func openCameraButtonTapped() {
         doAfterPermissionCheck { [weak self] in
            if self != nil {
//                self?.fromCamera = true
//                self!.didCapturePhoto?(UIImage(named: "img_dummy")!)
                let sourceType:UIImagePickerController.SourceType = UIImagePickerController.SourceType.camera
                if UIImagePickerController.isSourceTypeAvailable(
                    UIImagePickerController.SourceType.camera){
                    self!.cameraPicker.sourceType = sourceType
                    self!.cameraPicker.delegate = self
                    self!.cameraPicker.modalPresentationStyle = .fullScreen
                    self?.present(self!.cameraPicker, animated: false)
                }
            }
        }
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[.originalImage] as? UIImage {
            self.fromCamera = true
            self.fromCropClick = false
            self.didCapturePhoto?(pickedImage)
//            let cropVC = CustomCropViewController(item:pickedImage)
//            cropVC.fromCamera = true
//            self.navigationController?.pushViewController(cropVC, animated: true)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    
    func showMultipleSelection() {

        // Prevent desactivating multiple selection when using `minNumberOfItems`
        if YPConfig.library.minNumberOfItems > 1 && multipleSelectionEnabled {
            return
        }
        
        multipleSelectionEnabled = !multipleSelectionEnabled
        
        if multipleSelectionEnabled {
            if selection.isEmpty && YPConfig.library.preSelectItemOnMultipleSelection,
                delegate?.libraryViewShouldAddToSelection(indexPath: IndexPath(row: currentlySelectedIndex, section: 0),
                                                          numSelections: selection.count) ?? true {

                let asset = mediaManager.fetchResult[currentlySelectedIndex]
                selection = [
                    YPLibrarySelection(index: currentlySelectedIndex,
                                       cropRect: v.currentCropRect(),
                                       scrollViewContentOffset: v.assetZoomableView!.contentOffset,
                                       scrollViewZoomScale: v.assetZoomableView!.zoomScale,
                                       assetIdentifier: asset.localIdentifier,
                                       cutWidth: v.leftMaskHeight.constant,
                                       cutHeight: v.topMaskHeight.constant)
                ]
                v.multiselectCountLabel.text = String(format: "%02d", selection.count)

            }
        } else {
            self.isFirstTime = true
            selection.removeAll()
            if !YPConfig.showDrafts{
            self.v.cropImageButton.isHidden = false
            self.v.clickImageButton.isHidden = false
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
    
    func doAfterPermissionCheck(block:@escaping () -> Void) {
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
            if hasPermission && !strongSelf.initialized {
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
            if !multipleSelectionEnabled && YPConfig.library.preSelectItemOnMultipleSelection {
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
            mediaManager.updateCachedAssets(in: self.v.collectionView)
        }
    }
    
    var isFirstTime = true
    func changeAsset(_ asset: PHAsset) {
        latestImageTapped = asset.localIdentifier
        delegate?.libraryViewStartedLoadingImage()
        let completion = { (isLowResIntermediaryImage: Bool) in
            self.v.hideOverlayView()
            self.v.assetViewContainer.refreshSquareCropButton()
            self.singleImage = self.v.assetZoomableView.assetImageView.image
            if self.multipleSelectionEnabled{
                if self.isFirstTime{
                    self.isFirstTime = false
                self.v.leftMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.x
                self.v.rightMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.x
                self.v.bottomMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.y
                self.v.topMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.y
                    if (self.v.assetZoomableView.assetImageView.frame.width < self.v.assetZoomableView.assetImageView.frame.height)
                    {
//                        self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
//                        self.targetHeight = self.v.assetZoomableView.assetImageView.frame.height
                        let ratio = self.v.assetZoomableView.assetImageView.frame.width / self.v.assetZoomableView.assetImageView.frame.height
                        if ratio < 1.25 {
                            self.targetWidth = self.v.assetZoomableView.frame.width
                            self.targetHeight = self.v.assetZoomableView.frame.width * 1.25
                        }else{
                            self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                            self.targetHeight = self.v.assetZoomableView.assetImageView.frame.width * ratio
                        }
                    }else if  (self.v.assetZoomableView.assetImageView.frame.width > self.v.assetZoomableView.assetImageView.frame.height){
                        self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                        self.targetHeight = self.v.assetZoomableView.assetImageView.frame.height
                    }else{
                        self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                        self.targetHeight = self.v.assetZoomableView.assetImageView.frame.height
                    }
  
                self.view.setNeedsLayout()
                }else{
                    if self.selection.count > 1{
                            self.v.assetZoomableView.fitImage(true)
                            self.v.assetZoomableView.layoutSubviews()
                    }
                }
            }else{
                self.targetWidth = self.v.assetZoomableView.photoImageView.frame.width
                self.targetHeight = self.v.assetZoomableView.photoImageView.frame.height
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
                self.v.assetZoomableView.setImage(asset,
                                                  mediaManager: self.mediaManager,
                                                  storedCropPosition: self.fetchStoredCrop(),
                                                  completion: completion,
                                                  updateCropInfo: updateCropInfo)
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
    
    func changeAssetDraft(_ asset: UIImage) {
       // latestImageTapped = asset.localIdentifier
        delegate?.libraryViewStartedLoadingImage()
        let completion = { (isLowResIntermediaryImage: Bool) in
            self.v.hideOverlayView()
            DispatchQueue.main.async {
                self.v.assetViewContainer.refreshSquareCropButton()
            }
            self.singleImage = self.v.assetZoomableView.assetImageView.image
            if self.multipleSelectionEnabled{
                if self.isFirstTime{
                    self.isFirstTime = false
                self.v.leftMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.x
                self.v.rightMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.x
                self.v.bottomMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.y
                self.v.topMaskHeight.constant = self.v.assetZoomableView.assetImageView.frame.origin.y
                    if (self.v.assetZoomableView.assetImageView.frame.width < self.v.assetZoomableView.assetImageView.frame.height)
                    {
//                        self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
//                        self.targetHeight = self.v.assetZoomableView.assetImageView.frame.height
                        let ratio = self.v.assetZoomableView.assetImageView.frame.width / self.v.assetZoomableView.assetImageView.frame.height
                        if ratio < 1.25 {
                            self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                            self.targetHeight = self.v.assetZoomableView.assetImageView.frame.width * 1.25
                        }else{
                            self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                            self.targetHeight = self.v.assetZoomableView.assetImageView.frame.width * ratio
                        }
                    }else if  (self.v.assetZoomableView.assetImageView.frame.width > self.v.assetZoomableView.assetImageView.frame.height){
                        self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                        self.targetHeight = self.v.assetZoomableView.assetImageView.frame.height
                    }else{
                        self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
                        self.targetHeight = self.v.assetZoomableView.assetImageView.frame.height
                    }
  
                self.view.setNeedsLayout()
                }else{
                    if self.selection.count > 1{
                            self.v.assetZoomableView.fitImage(true)
                            self.v.assetZoomableView.layoutSubviews()
                    }
                }
            }else{
                self.targetWidth = self.v.assetZoomableView.photoImageView.frame.width
                self.targetHeight = self.v.assetZoomableView.photoImageView.frame.height
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
        
        if shouldUpdateOnlyIfNil && selection[selectedAssetIndex].scrollViewContentOffset != nil {
            return
        }
        
        // Fill new values
        var selectedAsset = selection[selectedAssetIndex]
        selectedAsset.scrollViewContentOffset = v.assetZoomableView.contentOffset
        selectedAsset.scrollViewZoomScale = v.assetZoomableView.zoomScale
        selectedAsset.cutWidth = v.leftMaskHeight.constant
        selectedAsset.cutHeight = v.topMaskHeight.constant
        selectedAsset.cropRect = v.currentCropRect()
        
        // Replace
        selection.remove(at: selectedAssetIndex)
        selection.insert(selectedAsset, at: selectedAssetIndex)
    }
    //TGP
    private func multiSelectionCount(){
        if !YPConfig.showDrafts || !v.showDraftImages{
        DispatchQueue.main.async {
            if self.multipleSelectionEnabled{
                if self.selection.count > 1
                {
                    self.v.cropImageButton.isHidden = true
                    self.v.clickImageButton.isHidden = true
                    self.v.multiselectCountLabel.text = String(format: "%02d", self.selection.count)
                }else{
                    self.v.cropImageButton.isHidden = false
                    self.v.clickImageButton.isHidden = false
                    self.v.multiselectCountLabel.text = String(format: "%02d", 1)
                }
            }else{
                self.v.cropImageButton.isHidden = false
                self.v.clickImageButton.isHidden = false
            }
        }
        }
    }
    
    internal func fetchStoredCrop() -> YPLibrarySelection? {
        multiSelectionCount()
        if self.multipleSelectionEnabled,
            self.selection.contains(where: { $0.index == self.currentlySelectedIndex }) {
            guard let selectedAssetIndex = self.selection
                .firstIndex(where: { $0.index == self.currentlySelectedIndex }) else {
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
                                   cutWidth:CGFloat,
                                   cutHeight:CGFloat,
                                   callback: @escaping (_ photo: UIImage, _ exif: [String: Any]) -> Void) {
        delegate?.libraryViewDidTapNext()
        let cropRect = withCropRect ?? DispatchQueue.main.sync { v.currentCropRect() }
        let ts = targetSize(for: asset, cropRect: cropRect)
        mediaManager.imageManager?.fetchImage(for: asset, cropRect: cropRect,cutWidth: cutWidth,cutHeight: cutHeight, targetSize: ts, callback: callback)
    }
    
    private func fetchVideoAndApplySettings(for asset: PHAsset,
                                            withCropRect rect: CGRect? = nil,
                                            callback: @escaping (_ videoURL: URL?) -> Void) {
        let normalizedCropRect = rect ?? DispatchQueue.main.sync { v.currentCropRect() }
        let ts = targetSize(for: asset, cropRect: normalizedCropRect)
        let xCrop: CGFloat = normalizedCropRect.origin.x * CGFloat(asset.pixelWidth)
        let yCrop: CGFloat = normalizedCropRect.origin.y * CGFloat(asset.pixelHeight)
        let resultCropRect = CGRect(x: xCrop,
                                    y: yCrop,
                                    width: ts.width,
                                    height: ts.height)
        
        guard fitsVideoLengthLimits(asset: asset) else {
            return
        }
        
        if YPConfig.video.automaticTrimToTrimmerMaxDuration {
            fetchVideoAndCropWithDuration(for: asset,
                                          withCropRect: resultCropRect,
                                          duration: YPConfig.video.trimmerMaxDuration,
                                          callback: callback)
        } else {
            delegate?.libraryViewDidTapNext()
            mediaManager.fetchVideoUrlAndCrop(for: asset, cropRect: resultCropRect, callback: callback)
        }
    }
    
    private func fetchVideoAndCropWithDuration(for asset: PHAsset,
                                               withCropRect rect: CGRect,
                                               duration: Double,
                                               callback: @escaping (_ videoURL: URL?) -> Void) {
        delegate?.libraryViewDidTapNext()
        let timeDuration = CMTimeMakeWithSeconds(duration, preferredTimescale: 1000)
        mediaManager.fetchVideoUrlAndCropWithDuration(for: asset,
                                                      cropRect: rect,
                                                      duration: timeDuration,
                                                      callback: callback)
    }
    
    public func selectedMedia(photoCallback: @escaping (_ photo: YPMediaPhoto) -> Void,
                              videoCallback: @escaping (_ videoURL: YPMediaVideo) -> Void,
                              multipleItemsCallback: @escaping (_ items: [YPMediaItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            
            let selectedAssets: [(asset: PHAsset, cropRect: CGRect?, cutHeight:CGFloat, cutWidth:CGFloat?)] = self.selection.map {
                guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [$0.assetIdentifier],
                                                      options: PHFetchOptions()).firstObject else { fatalError() }
                return (asset, $0.cropRect,$0.cutHeight,$0.cutWidth)
            }
            
            // Multiple selection
            if self.multipleSelectionEnabled && self.selection.count > 1 {
                
                for asset in selectedAssets {
                    if self.fitsVideoLengthLimits(asset: asset.asset) == false {
                        return
                    }
                }
                
                // Fill result media items array
                var resultMediaItems: [YPMediaItem] = []
                let asyncGroup = DispatchGroup()
                
                var assetDictionary = Dictionary<PHAsset?, Int>()
                for (index, assetPair) in selectedAssets.enumerated() {
                    assetDictionary[assetPair.asset] = index
                }
//                self.targetWidth = self.targetSize(for: selectedAssets[0].asset, cropRect: selectedAssets[0].cropRect ?? DispatchQueue.main.sync { self.v.currentCropRect() }).width
//                self.targetHeight = self.targetSize(for: selectedAssets[0].asset, cropRect: selectedAssets[0].cropRect ?? DispatchQueue.main.sync { self.v.currentCropRect() }).height
//                let ratio = self.targetWidth / self.targetHeight
//                if self.targetWidth > self.targetHeight {
//                    self.targetHeight = self.targetWidth / ratio
//                    self.targetWidth = self.v.assetZoomableView.assetImageView.frame.width
//                }else{
//                    self.targetWidth = self.targetWidth / ratio
//                    self.targetHeight = self.v.assetZoomableView.assetImageView.frame.width
//                }
                for asset in selectedAssets {
                    asyncGroup.enter()
                    
                    switch asset.asset.mediaType {
                    case .image:
                        self.fetchImageAndCrop(for: asset.asset, withCropRect: asset.cropRect,
                                               cutWidth: asset.cutWidth!,
                                               cutHeight: asset.cutHeight) { image, exifMeta in
                            let photo = YPMediaPhoto(image: image.resizedImageIfNeeded(),
                                                     exifMeta: exifMeta, asset: asset.asset)
                            resultMediaItems.append(YPMediaItem.photo(p: photo))
                            asyncGroup.leave()
                        }
                        
                    case .video:
                        self.fetchVideoAndApplySettings(for: asset.asset,
                                                             withCropRect: asset.cropRect) { videoURL in
                            if let videoURL = videoURL {
                                let videoItem = YPMediaVideo(thumbnail: thumbnailFromVideoPath(videoURL),
                                                             videoURL: videoURL, asset: asset.asset)
                                resultMediaItems.append(YPMediaItem.video(v: videoItem))
                            } else {
                                print("YPLibraryVC -> selectedMedia -> Problems with fetching videoURL.")
                            }
                            asyncGroup.leave()
                        }
                    default:
                        break
                    }
                }
                
                asyncGroup.notify(queue: .main) {
                    //TODO: sort the array based on the initial order of the assets in selectedAssets
                    resultMediaItems.sort { (first, second) -> Bool in
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
                    self.fetchVideoAndApplySettings(for: asset, callback: { videoURL in
                        DispatchQueue.main.async {
                            if let videoURL = videoURL {
                                self.delegate?.libraryViewFinishedLoading()
                                let video = YPMediaVideo(thumbnail: thumbnailFromVideoPath(videoURL),
                                                         videoURL: videoURL, asset: asset)
                                videoCallback(video)
                            } else {
                                print("YPLibraryVC -> selectedMedia -> Problems with fetching videoURL.")
                            }
                        }
                    })
                case .image:
                    self.fetchImageAndCrop(for: asset,
                                           cutWidth: selectedAssets.first!.cutWidth!,
                                           cutHeight:selectedAssets.first!.cutHeight)
                    { image, exifMeta in
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
extension  YPLibraryVC:  UIPickerViewDelegate, UIPickerViewDataSource {

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
        self.v.imageDropDownTextField.text = YPConfig.dropdownArray[row]
        if (YPConfig.dropdownArray[row] == "Draft"){
            isFirstTime = true
            if (YPConfig.draftImages.count > 0){
                multipleSelectionEnabled = false
                selectedDraftItem = YPConfig.draftImages[0]
                loadDrafts(draftItem: YPConfig.draftImages, showDraft: true)
            }else{
                view.endEditing(true)
                let alert = UIAlertController(title: "No images available in drafts", message: "Draft gallery is empty.Add some artworks.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
                        alert.dismiss(animated: true, completion: nil)
                    }))
                self.present(alert, animated: true, completion: nil)
            }
        }else{
            isFirstTime = true
            var config = YPImagePickerConfiguration()
            config.showDrafts = false
            loadDrafts(draftItem: [], showDraft: false)
        }
        view.endEditing(true)
}
    
}
