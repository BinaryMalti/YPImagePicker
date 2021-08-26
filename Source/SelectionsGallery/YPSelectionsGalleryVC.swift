//
//  SelectionsGalleryVC.swift
//  YPImagePicker
//
//  Created by Nik Kov || nik-kov.com on 09.04.18.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit
import Brightroom

public class YPSelectionsGalleryVC: UIViewController, YPSelectionsGalleryCellDelegate {
    
    override public var prefersStatusBarHidden: Bool { return YPConfig.hidesStatusBar }
    
    public var items: [YPMediaItem] = []
    public var didFinishHandler: ((_ clickType:Int,_ gallery: YPSelectionsGalleryVC, _ items: [YPMediaItem]) -> Void)?
    private var lastContentOffsetX: CGFloat = 0
    
    var v = YPSelectionsGalleryView()
    public var cropHeight : CGFloat = 0.0
    public var cropWidth : CGFloat = 0.0
    var bottomView = YPGalleryBottomView()
    internal var fromSaveAsDraft = false
    public var targetHeight : CGFloat = 200.0
    public override func loadView() { view = v }

    public required init(items: [YPMediaItem],
                         
                         didFinishHandler:
                            @escaping ((_ clickType:Int,_ gallery: YPSelectionsGalleryVC,
                                        _ items: [YPMediaItem]) -> Void)) {
        super.init(nibName: nil, bundle: nil)
        self.items = items
        self.didFinishHandler = didFinishHandler
        let bundle = Bundle(for: YPPickerVC.self)
        let nib = UINib(nibName: "YPGalleryBottomView", bundle: bundle)
        bottomView = nib.instantiate(withOwner: self, options: nil)[0] as! YPGalleryBottomView
        self.v.viewB.addSubview(bottomView)
        bottomView.frame = CGRect(x:0, y: 0, width: self.v.viewB.frame.width, height: self.v.viewB.frame.height)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func saveAsDraftClick(sender: UIButton) {
        didFinishHandler?(4,self, items)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        // Register collection view cell
        v.collectionView.register(YPSelectionsGalleryCell.self, forCellWithReuseIdentifier: "item")
        v.collectionView.dataSource = self
        v.collectionView.delegate = self
        if #available(iOS 11.0, *) {
            v.collectionView.dragInteractionEnabled = true
            v.collectionView.dragDelegate = self
            v.collectionView.dropDelegate = self
        }

        self.addBackButtonItem(title: "Select Artwork", saveAsDraft: true, isFromcrop: false)
        self.bottomView.forwardButton.addTarget(self, action: #selector(done), for: .touchUpInside)
        
        // Setup navigation bar
//        navigationItem.rightBarButtonItem = UIBarButtonItem(title: YPConfig.wordings.next,
//                                                            style: .done,
//                                                            target: self,
//                                                            action: #selector(done))
//        navigationItem.rightBarButtonItem?.tintColor = YPConfig.colors.tintColor
//        navigationItem.rightBarButtonItem?.setFont(font: YPConfig.fonts.rightBarButtonFont, forState: .disabled)
//        navigationItem.rightBarButtonItem?.setFont(font: YPConfig.fonts.rightBarButtonFont, forState: .normal)
//        navigationController?.navigationBar.setTitleFont(font: YPConfig.fonts.navigationBarTitleFont)
        if (items.count > 1){
            bottomView.deleteButton.isHidden = false
        }else{
            bottomView.deleteButton.isHidden = true
        }
        bottomView.editButton.addTarget(self, action: #selector(editImage), for: .touchUpInside)
        bottomView.deleteButton.addTarget(self, action: #selector(deleteImage), for: .touchUpInside)
        
        YPHelper.changeBackButtonIcon(self)
        YPHelper.changeBackButtonTitle(self)
    }
    
    @objc
    private func editImage(){
        let indexPathCenter = findCenterIndex()
        for i in 0..<items.count {
            if (i == indexPathCenter.row){
                let selectedItem = items[i]
                switch selectedItem {
                case .photo(let photo):
                    if let name = photo.imageName{
                        let imageProvidr: ImageProvider = .init(image: photo.image) // url, data supported.
                        let controller = ClassicImageEditViewController(imageProvider: imageProvidr)
                        controller.handlers.didEndEditing = { [weak self] controller, stack in
                          guard let self = self else { return }
                          controller.dismiss(animated: true, completion: nil)

                          try! stack.makeRenderer().render { result in
                            switch result {
                            case let .success(rendered):
                               let saved = YPPhotoSaver.saveImageToDirectory(imageName: name, image: rendered.uiImage, folderName: YPConfig.albumName)
                                if saved != nil {
                                    let editedImage =  YPPhotoSaver.loadImage(withName: name, from: YPConfig.albumName)
                                    photo.modifiedImage = editedImage
                                    self.items.remove(at: i)
                                    self.items.insert(selectedItem, at: i)
                                    self.v.collectionView.performBatchUpdates {
                                        let cell = self.v.collectionView.cellForItem(at: indexPathCenter) as! YPSelectionsGalleryCell
                                        cell.imageView.image = editedImage
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
        didFinishHandler?(2,self, items)
    }
    
    public func selectionsGalleryCellDidTapRemove(cell: YPSelectionsGalleryCell) {
        let alert = UIAlertController(title: "Do you want to delete this artwork?", message: "You cannot undo this action", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
                alert.dismiss(animated: true, completion: nil)
            }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction!) in
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
            //            v.collectionView.performBatchUpdates({
            //                v.collectionView.deleteItems(at: [indexPath])
            //            }, completion: { _ in })
                self.v.collectionView.reloadData()
                    }
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
            if indexPath.row == 0{
                cell.imageView.contentMode = .scaleAspectFit
            }else{
                cell.imageView.contentMode = .scaleAspectFill
            }
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
                self.items.remove(at: sourceIndexPath.item)
                self.items.insert(item.dragItem.localObject as! YPMediaItem, at: desinationIndexpath.item)
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [desinationIndexpath])
            }, completion: nil)
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
class ScaledHeightImageView: UIImageView {

    override var intrinsicContentSize: CGSize {

        if let myImage = self.image {
            let myImageWidth = myImage.size.width
            let myImageHeight = myImage.size.height
            var myViewWidth = self.frame.size.width
            if myImageWidth > myImageHeight{
                myViewWidth = myViewWidth - 24
            }else if myImageWidth < myImageHeight{
                myViewWidth = myViewWidth - 24
            }else{
                myViewWidth = self.frame.size.width
            }
 
            let ratio = myViewWidth/myImageWidth
            let scaledHeight = myImageHeight * ratio

            return CGSize(width: myViewWidth, height: scaledHeight)
        }

        return CGSize(width: -1.0, height: -1.0)
    }

}
extension UIImageView {
    var contentClippingRect: CGRect {
        guard let image = image else { return bounds }
        guard contentMode == .scaleAspectFit else { return bounds }
        guard image.size.width > 0 && image.size.height > 0 else { return bounds }

        let scale: CGFloat
        if image.size.width > image.size.height {
            scale = bounds.width / image.size.width
        } else {
            scale = bounds.height / image.size.height
        }

        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let x = (bounds.width - size.width) / 2.0
        let y = (bounds.height - size.height) / 2.0

        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
