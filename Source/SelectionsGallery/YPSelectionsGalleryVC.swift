//
//  SelectionsGalleryVC.swift
//  YPImagePicker
//
//  Created by Nik Kov || nik-kov.com on 09.04.18.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit

public class YPSelectionsGalleryVC: UIViewController, YPSelectionsGalleryCellDelegate {
    
    override public var prefersStatusBarHidden: Bool { return YPConfig.hidesStatusBar }
    
    public var items: [YPMediaItem] = []
    public var didFinishHandler: ((_ clickType:Int,_ gallery: YPSelectionsGalleryVC, _ items: [YPMediaItem]) -> Void)?
    private var lastContentOffsetX: CGFloat = 0
    
    var v = YPSelectionsGalleryView()
    var bottomView = YPGalleryBottomView()
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

        self.addBackButtonItem(title: "Select Artwork", saveAsDraft: true)
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
                switch items[i] {
                case .photo(let photo):
                    photo.modifiedImage = photo.originalImage
                case .video(v: _): break
                }
            }
        }
//        let element = items.remove(at: indexPathCenter.row)
//        items.insert(element, at: 0)
        didFinishHandler?(2,self, items)
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
        if YPConfig.shouldSaveNewPicturesToAlbum {
            for m in items {
                if case let .photo(p) = m, let modifiedImage = p.modifiedImage {
                    YPPhotoSaver.trySaveImage(modifiedImage, inAlbumNamed: YPConfig.albumName)
                }
            }
        }
        didFinishHandler?(0,self, items)
    }
    
    public func selectionsGalleryCellDidTapRemove(cell: YPSelectionsGalleryCell) {
        if let indexPath = v.collectionView.indexPath(for: cell) {
            items.remove(at: indexPath.row)
//            v.collectionView.performBatchUpdates({
//                v.collectionView.deleteItems(at: [indexPath])
//            }, completion: { _ in })
            v.collectionView.reloadData()
        }
    }
}

// MARK: - Collection View
extension YPSelectionsGalleryVC: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
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
            cell.imageView.image = photo.image
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
