//
//  SelectionsGalleryVC.swift
//  YPImagePicker
//
//  Created by Nik Kov || nik-kov.com on 09.04.18.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit
import Brightroom

open class YPSelectionsGalleryVC: UIViewController, YPSelectionsGalleryCellDelegate {
    
    override public var prefersStatusBarHidden: Bool { return YPConfig.hidesStatusBar }
    public static var contentMode : UIImageView.ContentMode = .scaleAspectFill
    public var items: [YPMediaItem] = []
   // public var finalItems: [YPMediaItem] = []
    public var didFinishHandler: ((_ clickType:Int,_ gallery: YPSelectionsGalleryVC, _ items: [YPMediaItem]) -> Void)?
    private var lastContentOffsetX: CGFloat = 0
    public var isFromPublishedArtWork: Bool = false
     var v = YPSelectionsGalleryView()
    public var cropHeight : CGFloat = 0.0
    public var cropWidth : CGFloat = 0.0
    var bottomView = YPGalleryBottomView()
    internal var fromSaveAsDraft = false
    public var isFromEdit = false
    public var fromCamera = false
    public var targetHeight : CGFloat = 200.0
    var config = YPImagePickerConfiguration.shared
    public var isReorderPerformed = false
    public var collectioViewHeight : CGFloat = 0.0
    public override func loadView() { view = v }

    public required init(items: [YPMediaItem],
                         config : YPImagePickerConfiguration,
                         didFinishHandler:
                            @escaping ((_ clickType:Int,_ gallery: YPSelectionsGalleryVC,
                                        _ items: [YPMediaItem]) -> Void)) {
        super.init(nibName: nil, bundle: nil)
        self.items = items
        self.config = config
        self.didFinishHandler = didFinishHandler
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func saveAsDraftClick(sender: UIButton) {
        if fromCamera {
            didFinishHandler?(4,self, items)//title view navigation from camera
        }else{
            if isFromEdit {
                didFinishHandler?(5,self, items)//artwork preview navigation
            }else{
                didFinishHandler?(4,self, items)//title view navigation
            }
        }
    }

//    func cropImage(imageToCrop:UIImage, toRect rect:CGRect) -> UIImage{
//        let imageRef:CGImage = imageToCrop.cgImage!.cropping(to: rect)!
//        let cropped:UIImage = UIImage(cgImage:imageRef)
//        return cropped
//    }

    open override func viewWillAppear(_ animated: Bool) {
        self.isFromPublishedArtWork = UserDefaults.standard.bool(forKey: "artwork_published")
        if isFromPublishedArtWork == true {
            self.addBackButtonItem(title: "Artwork", saveAsDraft: true, isFromcrop: false, isForEdit: isFromEdit)
        } else if isFromEdit {
            self.addBackButtonItem(title: "My dashboard", saveAsDraft: true, isFromcrop: false, isForEdit: isFromEdit)
        }else{
            self.addBackButtonItem(title: "Select Artwork", saveAsDraft: true, isFromcrop: false, isForEdit: isFromEdit)
        }

        if isFromEdit{
            v.collectionView.height(cropHeight + 70)
        }
        if collectioViewHeight  != 0.0{
            v.collectionView.height(collectioViewHeight)
        }
 

    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if items.count == 1{
//            let sideMargin: CGFloat = 20
//            let overlapppingNextPhoto: CGFloat = 37
//            let screenWidth = YPImagePickerConfiguration.screenWidth
//            let collectionViewScreenWidth = screenWidth - (sideMargin + overlapppingNextPhoto)
            let totalWidth = cropWidth * CGFloat(items.count)
            let totalSpacingWidth : CGFloat = 0.0
            let leftInset = (YPImagePickerConfiguration.screenWidth - CGFloat(totalWidth + totalSpacingWidth)) / 2
                let rightInset = leftInset
            let totalHeight = cropHeight * CGFloat(items.count)
            let topInset = (self.view.frame.height - totalHeight)/2
          let layout =  v.collectionView.collectionViewLayout as? YPGalleryCollectionViewFlowLayout
            layout?.sectionInset = UIEdgeInsets(top: 0, left: leftInset, bottom: 0, right: rightInset)
        }else{
            
        }
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        let bundle = Bundle(for: YPPickerVC.self)
        let nib = UINib(nibName: "YPGalleryBottomView", bundle: bundle)
        bottomView = nib.instantiate(withOwner: self, options: nil)[0] as! YPGalleryBottomView
        self.v.viewB.addSubview(bottomView)
        bottomView.frame = CGRect(x:0, y: 0, width: self.v.viewB.frame.width, height: self.v.viewB.frame.height)
        if YPImagePickerConfiguration.shared.screens != [.library]{
            YPImagePickerConfiguration.shared = config
        }
        // Register collection view cell
        v.collectionView.register(YPSelectionsGalleryCell.self, forCellWithReuseIdentifier: "item")
        if isFromEdit{
            v.collectionView.height(cropHeight + 70)
        }
        if collectioViewHeight  != 0.0{
            v.collectionView.height(collectioViewHeight)
        }
        v.collectionView.dataSource = self
        v.collectionView.delegate = self
        v.collectionView.dragInteractionEnabled = true
        v.collectionView.dragDelegate = self
        v.collectionView.dropDelegate = self
        v.collectionView.reloadData()
        let longString = bottomView.pictureLabel.text!
        let longestWord = "picture (01) "
        let longestWordRange = (longString as NSString).range(of: longestWord)
        let attributedString = NSMutableAttributedString(string: longString, attributes: [NSAttributedString.Key.font : YPConfig.fonts.galleryNoteFont])
        attributedString.setAttributes([NSAttributedString.Key.font : YPConfig.fonts.pickerTitleFont, NSAttributedString.Key.foregroundColor : UIColor.black], range: longestWordRange)
        bottomView.pictureLabel.attributedText = attributedString
        if isFromEdit {
            self.addBackButtonItem(title: "My dashboard", saveAsDraft: true, isFromcrop: false, isForEdit: isFromEdit)
        }else{
            self.addBackButtonItem(title: "Select Artwork", saveAsDraft: true, isFromcrop: false, isForEdit: isFromEdit)
        }
        self.bottomView.forwardButton.addTarget(self, action: #selector(done), for: .touchUpInside)
        self.bottomView.backButton.addTarget(self, action: #selector(backButtonClick(sender:)), for: .touchUpInside)
        if (items.count > 1){
            bottomView.deleteButton.isHidden = false
        }else{
            bottomView.deleteButton.isHidden = true
        }
        bottomView.editButton.addTarget(self, action: #selector(editImage), for: .touchUpInside)
        bottomView.deleteButton.addTarget(self, action: #selector(deleteImage), for: .touchUpInside)
        YPHelper.changeBackButtonIcon(self)
        YPHelper.changeBackButtonTitle(self)
        if items.count == 1{
//            let sideMargin: CGFloat = 20
//            let overlapppingNextPhoto: CGFloat = 37
//            let screenWidth = YPImagePickerConfiguration.screenWidth
//            let collectionViewScreenWidth = screenWidth - (sideMargin + overlapppingNextPhoto)
            let totalWidth = cropWidth * CGFloat(items.count)
            let totalSpacingWidth : CGFloat = 0.0
            let leftInset = (YPImagePickerConfiguration.screenWidth - CGFloat(totalWidth + totalSpacingWidth)) / 2
                let rightInset = leftInset
            let totalHeight = cropHeight * CGFloat(items.count)
            let topInset = (self.view.frame.height - totalHeight)/2
          let layout =  v.collectionView.collectionViewLayout as? YPGalleryCollectionViewFlowLayout
            layout?.sectionInset = UIEdgeInsets(top: 0, left: leftInset, bottom: 0, right: rightInset)
        }
       // updateArtworkToLocalDirecotry()
    }
    
//    func updateArtworkToLocalDirecotry(){
//        if !isFromEdit {
//            finalItems.removeAll()
//            let ivRect = CGRect(x: 0, y: 0, width: cropWidth, height: cropHeight)
//            let imageView = UIImageView(frame: ivRect)
//            imageView.contentMode = .scaleAspectFit
//            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleBottomMargin, .flexibleRightMargin, .flexibleLeftMargin, .flexibleTopMargin]
//            let ivsize = imageView.bounds.size
//            for item in items{
//                switch item {
//                case .photo(let photo):
//                    if #available(iOS 13.0, *) {
//                        self.showActivityIndicator()}
//                    imageView.image = photo.image
//                    var scale : CGFloat = ivsize.width / imageView.image!.size.width
//                    if imageView.image!.size.height * scale < ivsize.height {
//                        scale = ivsize.height / imageView.image!.size.height
//                    }
//                    let croppedImsize = CGSize(width:ivsize.width/scale, height:ivsize.height/scale)
//                    let croppedImrect =
//                        CGRect(origin: CGPoint(x: (imageView.image!.size.width-croppedImsize.width)/2.0,
//                                               y: (imageView.image!.size.height-croppedImsize.height)/2.0),
//                               size: croppedImsize)
//                    let cropImage = cropImage(imageToCrop: photo.originalImage, toRect: croppedImrect)
//                   // YPPhotoSaver.clearAllFile()
//                    if let imagePath = saveImage(image: cropImage, imageName: photo.imageName!)
//                   {
//                        let artwork = YPMediaPhoto(image: cropImage, exifMeta: nil, fromCamera: photo.fromCamera, asset: photo.asset, url: imagePath, widthRatio: cropWidth, heightRatio: cropHeight, imageName: photo.imageName)
//                    let artworkMedia = YPMediaItem.photo(p: artwork)
//                        if #available(iOS 13.0, *) {
//                            self.hideActivityIndicator()
//                        }
//                    finalItems.append(artworkMedia)
//                   }
//                default:
//                    break
//                }
//            }
//
//        }
//    }
    
    //TGP -Find & Edit center image in collection view using Brightroom Library
    @objc private func editImage(){
        let indexPathCenter = findCenterIndex()
        for i in 0..<items.count {
            if (i == indexPathCenter.row){
                let selectedItem = items[i]
                switch selectedItem {
                case .photo(let photo):
                    if let name = photo.imageName{
                        let imageProvidr: ImageProvider = .init(image: photo.image) // url, data supported.
                        var options = ClassicImageEditOptions()
                          options.croppingAspectRatio = nil
                        let controller = ClassicImageEditViewController(imageProvider: imageProvidr,options: options)
                        controller.handlers.didEndEditing = { [weak self] controller, stack in
                          guard let self = self else { return }
                          controller.dismiss(animated: true, completion: nil)
                            if #available(iOS 13.0, *) {
                                self.showActivityIndicator()
                            }
                          try! stack.makeRenderer().render { result in
                            switch result {
                            case let .success(rendered):
                               let saved = YPPhotoSaver.saveImageToDirectory(imageName: name, image: rendered.uiImage, folderName: YPConfig.albumName)
                                if saved != nil {
                                    let editedImage =  YPPhotoSaver.loadImage(withName: name, from: YPConfig.albumName)
                                    photo.modifiedImage = editedImage
                                    photo.url = saved
                                    self.items.remove(at: i)
                                    self.items.insert(selectedItem, at: i)
                                    self.isReorderPerformed = true
                                    self.v.collectionView.performBatchUpdates {
                                        let cell = self.v.collectionView.cellForItem(at: indexPathCenter) as! YPSelectionsGalleryCell
                                        cell.imageView.image = editedImage
                                        if #available(iOS 13.0, *) {
                                            self.hideActivityIndicator()
                                        }
                                    }
                                }
                                
                            case let .failure(error):
                              print(error)
                            }
                          }
                        }
                        controller.handlers.didCancelEditing = { controller in
                                controller.dismiss(animated: true, completion: nil)
                        }
                        let navVC = UINavigationController(rootViewController: controller)
                        navVC.view.backgroundColor = .white
                        navVC.toolbar.isHidden = true
                        navVC.navigationBar.tintColor = .black
                        navVC.navigationBar.backgroundColor = .white
                        navVC.navigationBar.shadowImage = UIImage()
                        navVC.navigationBar.isTranslucent = false
                        navVC.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.compact)
                        navVC.modalPresentationStyle = .fullScreen
                        self.navigationController?.present(navVC, animated: true)
                    }
           
                case .video(v: _): break
                }
            }
        }
        
        
//        let element = items.remove(at: indexPathCenter.row)
//        items.insert(element, at: 0)
       // didFinishHandler?(2,self, items)
    }
    
    @objc
    private func deleteImage(){
        let indexPathCenter = findCenterIndex()
        let cellDelete:YPSelectionsGalleryCell = v.collectionView.cellForItem(at: indexPathCenter) as! YPSelectionsGalleryCell
        selectionsGalleryCellDidTapRemove(cell: cellDelete)
        
    }
    
    private func findCenterIndex() -> IndexPath {
        let center = self.view.convert(v.collectionView.center, to: v.collectionView)
        let index = v.collectionView.indexPathForItem(at: center)
        print(index ?? "index not found")
        return index ?? IndexPath()
    }
    
    @objc
    private func done() {
        // Save new images to the photo album.
//        if YPConfig.shouldSaveNewPicturesToAlbum {
//            for m in items {
//                if case let .photo(p) = m, let modifiedImage = p.modifiedImage {
//                    YPPhotoSaver.trySaveImage(modifiedImage, inAlbumNamed: YPConfig.albumName)
//                }
//            }
//        }
        
        if isFromEdit {
            didFinishHandler?(2,self, items)
        }else{
            didFinishHandler?(2,self, items)
        }
    }
    
//    override func backButtonClick(sender: UIButton) {
//        if isReorderPerformed{
//            let alert = UIAlertController(title: "Discard Changes", message: "You will loose the changes performed", preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
//                    alert.dismiss(animated: true, completion: nil)
//                }))
//            alert.addAction(UIAlertAction(title: "Discard", style: .destructive, handler: { (action: UIAlertAction!) in
//                alert.dismiss(animated: true, completion: nil)
//                self.navigationController?.popViewController(animated: true)
//            }))
//            self.present(alert, animated: true, completion: nil)
//        }else{
//           // self.dismiss(animated: true, completion: nil)
//            self.navigationController?.popViewController(animated: true)
//        }
//    }
    
    public func selectionsGalleryCellDidTapRemove(cell: YPSelectionsGalleryCell) {
        let alert = UIAlertController(title: "Do you want to delete this artwork?", message: "You cannot undo this action", preferredStyle: .actionSheet)
          alert.addAction(UIAlertAction(title: "Delete", style: .destructive , handler:{ (UIAlertAction)in
            if let indexPath = self.v.collectionView.indexPath(for: cell) {
                switch self.items[indexPath.row]{
                        case .photo(p: let p):
                            if let imagePath = p.url{
                                do {
                                    try FileManager.default.removeItem(at: imagePath)
                                }catch{
                                    print("selectionsGalleryCellDidTapRemove:","url not found")
                                }
                            }
                        case .video(v: _):
                            break
                        }
                self.items.remove(at: indexPath.row)
//                if self.finalItems.count > 0{
//                    self.finalItems.remove(at: indexPath.row)
//                }
            //            v.collectionView.performBatchUpdates({
            //                v.collectionView.deleteItems(at: [indexPath])
            //            }, completion: { _ in })
                if self.items.count == 1{
                    self.bottomView.deleteButton.isHidden = true
                    let totalWidth = self.cropWidth * CGFloat(self.items.count)
                    let totalSpacingWidth : CGFloat = 0.0
                    let leftInset = (self.v.collectionView.frame.width - CGFloat(totalWidth + totalSpacingWidth)) / 2
                        let rightInset = leftInset
                    let layout =  self.v.collectionView.collectionViewLayout as? YPGalleryCollectionViewFlowLayout
                    layout?.sectionInset = UIEdgeInsets(top: 0, left: rightInset, bottom: 0, right: leftInset)
                }
                self.v.collectionView.reloadData()
                
                    }
            self.dismiss(animated: true, completion: nil)
          }))
          
          alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:{ (UIAlertAction)in
            self.dismiss(animated: true, completion: nil)
          }))
          self.present(alert, animated: true, completion: nil)
        }
}

// MARK: - Collection View
extension YPSelectionsGalleryVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: cropWidth, height: cropHeight)
    }
    
    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "item",
                                                            for: indexPath) as? YPSelectionsGalleryCell else {
            return UICollectionViewCell()
        }
        cell.delegate = self
        let item = items[indexPath.row]
        switch item {
        case .photo(let photo):
           // cell.imageView.frame = CGRect(x: 0, y: 0, width: cropWidth, height: cropHeight)
           // cell.imageView.backgroundColor = .clear
           // if items.count > 1{
               // cell.imageView.contentMode = YPSelectionsGalleryVC.contentMode}else{
                    cell.imageView.contentMode = .scaleAspectFit
                
              //  }
            cell.imageView.image = photo.originalImage
            cell.countLabel.text = String(format: "%02d",indexPath.row+1)
            cell.setEditable(YPConfig.showsPhotoFilters)
        case .video(let video):
            cell.imageView.image = video.thumbnail
            cell.setEditable(YPConfig.showsVideoTrimmer)
        }
        cell.removeButton.isHidden = YPConfig.gallery.hidesRemoveButton
        return cell
    }
    
    private func saveImage(image:UIImage,imageName:String) -> URL?{
        if let imagePath = YPPhotoSaver.saveImageToDirectory(imageName: imageName, image: image, folderName: YPConfig.albumName)
      {
        return imagePath
      }else{
        return nil
      }
    }
}

extension YPSelectionsGalleryVC: UICollectionViewDelegate {
    
        
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        var mediaFilterVC: IsMediaFilterVC?
        switch item {
        case .photo(let photo):
            if !YPConfig.filters.isEmpty, YPConfig.showsPhotoFilters {
                mediaFilterVC = YPPhotoFiltersVC(inputPhoto: photo, isFromSelectionVC: true)
            }
        case .video(let video):
            if YPConfig.showsVideoTrimmer {
                mediaFilterVC = YPVideoFiltersVC.initWith(video: video, isFromSelectionVC: true)
            }
        }
        
        mediaFilterVC?.didSave = { outputMedia in
            self.items[indexPath.row] = outputMedia
            collectionView.reloadData()
            self.dismiss(animated: true, completion: nil)
        }
        mediaFilterVC?.didCancel = {
            self.dismiss(animated: true, completion: nil)
        }
        if let mediaFilterVC = mediaFilterVC as? UIViewController {
            let navVC = UINavigationController(rootViewController: mediaFilterVC)
            navVC.navigationBar.isTranslucent = false
            present(navVC, animated: true, completion: nil)
        }
    }
    
    // Set "paging" behaviour when scrolling backwards.
    // This works by having `targetContentOffset(forProposedContentOffset: withScrollingVelocity` overriden
    // in the collection view Flow subclass & using UIScrollViewDecelerationRateFast
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let isScrollingBackwards = scrollView.contentOffset.x < lastContentOffsetX
        scrollView.decelerationRate = isScrollingBackwards
            ? UIScrollView.DecelerationRate.fast
            : UIScrollView.DecelerationRate.normal
        lastContentOffsetX = scrollView.contentOffset.x
    }
}
extension YPSelectionsGalleryVC: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    @available(iOS 11.0, *)
    public func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        var destinationIndexPath:IndexPath
        if let indexPath = coordinator.destinationIndexPath{
            destinationIndexPath = indexPath
        }else{
            let row = collectionView.numberOfItems(inSection: 0)
            destinationIndexPath = IndexPath(item: row-1, section: 0)
        }
        if coordinator.proposal.operation == .move{
            self.reorderItems(coordinator: coordinator, desinationIndexpath: destinationIndexPath, collectionView: collectionView)
        }
    }
    
    @available(iOS 11.0, *)
    func reorderItems(coordinator:UICollectionViewDropCoordinator,desinationIndexpath : IndexPath, collectionView:UICollectionView){
        if let item = coordinator.items.first,
           let sourceIndexPath = item.sourceIndexPath{
                collectionView.performBatchUpdates({
                    isReorderPerformed = true
                self.items.remove(at: sourceIndexPath.item)
                self.items.insert(item.dragItem.localObject as! YPMediaItem, at: desinationIndexpath.item)
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [desinationIndexpath])
            }, completion: {_ in
                collectionView.reloadSections(IndexSet(integer: 0))
            })
            coordinator.drop(item.dragItem, toItemAt:desinationIndexpath)
        }
    }
    
    @available(iOS 11.0, *)
    public func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }
    
    @available(iOS 11.0, *)
    public func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = items[indexPath.row]
        var itemData = UIImage()
        switch item {
        case .photo(let photo):
            itemData = photo.image
        case .video(v: _): break
        }
        let itemProvider = NSItemProvider(object: itemData)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    
}

fileprivate let overlayViewTag = 999
fileprivate let activityIndicatorTag = 1000
fileprivate let bgViewTag = 123456

@available(iOS 13.0, *)
extension UIViewController {
    
    func bindKeypad(to constraint: NSLayoutConstraint, constant: CGFloat? = -40) {
        
        let bottomConstraintSize: CGFloat = 20
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: OperationQueue.main) { [weak self, weak constraint] notification in
            
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                
                let moveSize = keyboardSize.height + bottomConstraintSize
                constraint?.constant = -moveSize
                self?.view.layoutIfNeeded()
            }
            
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: OperationQueue.main) { [weak self, weak constraint] _ in
            
            constraint?.constant = constant!
            self?.view.layoutIfNeeded()
        }
    }
    
    func showActivityIndicator(){
        guard !isDisplayingActivityIndicatorOverlay() else { return }
        let keyView = UIApplication.shared.windows.first { $0.isKeyWindow }
        guard let parentViewForOverlay = keyView ?? navigationController?.view ?? view else { return }
        
        //configure transparent bg
        let bgView = UIView()
        bgView.translatesAutoresizingMaskIntoConstraints = false
        bgView.backgroundColor = UIColor.clear
        bgView.tag = bgViewTag
        
        //configure overlay
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black
        overlay.alpha = 0.5
        overlay.tag = overlayViewTag
        overlay.layer.cornerRadius = 16.0
        
        //configure activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = UIColor.white
        activityIndicator.tag = activityIndicatorTag
        
        //add subviews
        parentViewForOverlay.addSubview(bgView)
        bgView.addSubview(overlay)
        bgView.addSubview(activityIndicator)
        //add overlay constraints
        bgView.heightAnchor.constraint(equalTo: parentViewForOverlay.heightAnchor).isActive = true
        bgView.widthAnchor.constraint(equalTo: parentViewForOverlay.widthAnchor).isActive = true
        overlay.widthAnchor.constraint(equalToConstant: 80.0).isActive = true
        overlay.heightAnchor.constraint(equalToConstant: 80.0).isActive = true
        overlay.centerXAnchor.constraint(equalTo: bgView.centerXAnchor).isActive = true
        overlay.centerYAnchor.constraint(equalTo: bgView.centerYAnchor).isActive = true
        
        //add indicator constraints
        activityIndicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor).isActive = true
        activityIndicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor).isActive = true
        
        //animate indicator
        activityIndicator.startAnimating()
    }
    
    func hideActivityIndicator() -> Void {
        let activityIndicator = getActivityIndicator()
        let bgView = getBgView()
        if let overlayView = getOverlayView() {
            UIView.animate(withDuration: 0.2, animations: {
                overlayView.alpha = 0.0
                activityIndicator?.stopAnimating()
            }) { (finished) in
                activityIndicator?.removeFromSuperview()
                overlayView.removeFromSuperview()
                bgView?.removeFromSuperview()
            }
        }
    }
    
    func isDisplayingActivityIndicatorOverlay() -> Bool {
        if let _ = getActivityIndicator(), let _ = getOverlayView() {
            return true
        }
        return false
    }
    
    private func getActivityIndicator() -> UIActivityIndicatorView? {
        let keyView = UIApplication.shared.windows.first { $0.isKeyWindow }
        guard let parentViewForOverlay = keyView ?? navigationController?.view ?? view else { return nil}
        return parentViewForOverlay.viewWithTag(activityIndicatorTag) as? UIActivityIndicatorView
    }
    
    private func getOverlayView() -> UIView? {
        let keyView = UIApplication.shared.windows.first { $0.isKeyWindow }
        guard let parentViewForOverlay = keyView ?? navigationController?.view ?? view else { return nil}
        return parentViewForOverlay.viewWithTag(overlayViewTag)
    }
    
    private func getBgView() -> UIView? {
        let keyView = UIApplication.shared.windows.first { $0.isKeyWindow }
        guard let parentViewForOverlay = keyView ?? navigationController?.view ?? view else { return nil}
        return parentViewForOverlay.viewWithTag(bgViewTag)
    }
    
}
