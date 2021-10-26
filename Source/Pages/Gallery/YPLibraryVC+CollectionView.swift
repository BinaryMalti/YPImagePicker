//
//  YPLibraryVC+CollectionView.swift
//  YPImagePicker
//
//  Created by Sacha DSO on 26/01/2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit
import Photos

extension YPLibraryVC {
    
    //TGP - To hide and show draft options and New Post options
    func loadDrafts(draftItem:[DraftItems],showDraft:Bool){
        v.draftItem = draftItem
        v.showDraftImages = showDraft
        setupCollectionView()
        if showDraft{
            v.cameraButton.isHidden = true
            v.cropImageButton.isHidden = true
            v.multiselectImageButton.isHidden = true
            v.multiselectCountLabel.text = ""
            let defaultAssetZoomableViewSize = self.v.assetViewContainer.frame.width
            self.v.zoomableHeightConstraint?.constant = defaultAssetZoomableViewSize
            self.v.zoomableWidthConstraint?.constant = defaultAssetZoomableViewSize
            self.v.assetZoomableView.isMultipleSelectionEnabled = false
            self.v.layoutIfNeeded()
            if self.v.isImageViewConstraintUpdated {
                self.v.assetZoomableView.centerAssetView()
            }
            self.v.assetZoomableView.fitImage(false)
            self.isFirstItemSelectedMultipleSelection = true
            self.isImageAlreadySelected = false
            selection.removeAll()
            v.assetViewContainer.setMultipleSelectionMode(on: multipleSelectionEnabled)
            v.toggleMultiselectButton(isOn: multipleSelectionEnabled)
            if self.selectedDraftItem?.image != nil {
                changeAssetDraft(self.selectedDraftItem!.image)
            }
            v.collectionView.reloadData()
            currentlySelectedIndex = 0
        }else{
            currentlySelectedIndex = 0
            v.cameraButton.isHidden = false
            v.cropImageButton.isHidden = false
            v.multiselectImageButton.isHidden = false
            v.collectionView.reloadData()
            refreshMediaRequest()
        }
    }
    
    var isLimitExceeded: Bool { return selection.count > YPConfig.library.maxNumberOfItems }
    
    func setupCollectionView() {
        v.collectionView.backgroundColor = YPConfig.colors.libraryScreenBackgroundColor
        v.collectionView.dataSource = self
        v.collectionView.delegate = self
        v.collectionView.register(YPLibraryViewCell.self, forCellWithReuseIdentifier: "YPLibraryViewCell")
        if !v.showDraftImages {
        // Long press on cell to enable multiple selection
        let longPressGR = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(longPressGR:)))
        longPressGR.minimumPressDuration = 0.5
        v.collectionView.addGestureRecognizer(longPressGR)
        }
    }
    
    /// When tapping on the cell with long press, clear all previously selected cells.
    @objc func handleLongPress(longPressGR: UILongPressGestureRecognizer) {
       
        if multipleSelectionEnabled || isProcessing || YPConfig.library.maxNumberOfItems <= 1 {
            return
        }
        if !v.showDraftImages{
            if longPressGR.state == .began {
                let point = longPressGR.location(in: v.collectionView)
                guard let indexPath = v.collectionView.indexPathForItem(at: point) else {
                    return
                }
                startMultipleSelection(at: indexPath)
            }
        }

    }
    
    func startMultipleSelection(at indexPath: IndexPath) {
        currentlySelectedIndex = indexPath.row
        multipleSelectioTapped()//tgp check this

        // Update preview.
        let selectedAsset = selection.filter{$0.index == indexPath.row};
        if selectedAsset.count > 0 && selectedAsset.first!.croppedImage != nil {
            changeAsset(mediaManager.fetchResult[indexPath.row],cropImage: selectedAsset.first!.croppedImage)
        }else{
            isFirstItemSelectedMultipleSelection = true
            changeAsset(mediaManager.fetchResult[indexPath.row])
            let firstSelection = selection.first!
            let asset = mediaManager.fetchResult[indexPath.item]
            if selection.first!.assetIdentifier != asset.localIdentifier{
            selection = [YPLibrarySelection(index: indexPath.row,
                                            cropRect: firstSelection.cropRect,
                                            scrollViewContentOffset: firstSelection.scrollViewContentOffset,
                                            scrollViewZoomScale: firstSelection.scrollViewZoomScale, assetIdentifier: asset.localIdentifier, croppedImage: nil)]
            }
        }
        // Bring preview down and keep selected cell visible.
        panGestureHelper.resetToOriginalState()
        if !panGestureHelper.isImageShown {
            v.collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
        }
       
        v.refreshImageCurtainAlpha()
        v.collectionView.reloadData()
    }
    
    // MARK: - Library collection view cell managing
    
    /// Removes cell from selection
    func deselect(indexPath: IndexPath) {
        if let positionIndex = selection.firstIndex(where: {
            $0.assetIdentifier == mediaManager.fetchResult[indexPath.row].localIdentifier
        }) {
            selection.remove(at: positionIndex)

            // Refresh the numbers
            var selectedIndexPaths = [IndexPath]()
            mediaManager.fetchResult.enumerateObjects { [unowned self] (asset, index, _) in
                if self.selection.contains(where: { $0.assetIdentifier == asset.localIdentifier }) {
                    selectedIndexPaths.append(IndexPath(row: index, section: 0))
                }
            }
            v.collectionView.reloadItems(at: selectedIndexPaths)
            
            // Replace the current selected image with the previously selected one
            if let lastIndex = selection.last?.index {
                            let previousIndexPath = IndexPath(item: lastIndex, section: 0)
                            v.collectionView.deselectItem(at: indexPath, animated: false)
                            v.collectionView.selectItem(at: previousIndexPath, animated: false, scrollPosition: [])
                            currentlySelectedIndex = previousIndexPath.row
                            changeAsset(mediaManager.fetchResult[previousIndexPath.row])
             }

            checkLimit()
        }
    }
    
    
    /// Adds cell to selection
    func addToSelection(indexPath: IndexPath) {
        if !(delegate?.libraryViewShouldAddToSelection(indexPath: indexPath, numSelections: selection.count) ?? true) {
            return
        }
        if v.showDraftImages {
            let draftImage = v.draftItem[indexPath.row]
            selection.append(YPLibrarySelection(index: indexPath.row,
                                                assetIdentifier: nil
            )
        )
        }else{
        let asset = mediaManager.fetchResult[indexPath.item]
        selection.append(
            YPLibrarySelection(
                index: indexPath.row,
                assetIdentifier: asset.localIdentifier
            )
        )
            checkLimit()

        }

    }
    
    func isInSelectionPool(indexPath: IndexPath) -> Bool {
        return selection.contains(where: {
            $0.assetIdentifier == mediaManager.fetchResult[indexPath.row].localIdentifier
        })
    }
    
    /// Checks if there can be selected more items. If no - present warning.
    func checkLimit() {
        v.maxNumberWarningView.isHidden = !isLimitExceeded || multipleSelectionEnabled == false
    }
}

extension YPLibraryVC: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if v.showDraftImages{
            
            return v.draftItem.count
        }
        
        let galleryCount = mediaManager.fetchResult.count
        print("galleryCount: \(galleryCount)")
        if galleryCount == 0 {
            showGalleryEmptyState()
        } else {
            hideGalleryEmptyState()
        }
        
        return galleryCount
    }
}

extension YPLibraryVC: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "YPLibraryViewCell",
                                                            for: indexPath) as? YPLibraryViewCell else {
                                                                fatalError("unexpected cell in collection view")
        }
        cell.multipleSelectionIndicator.selectionColor =
            YPConfig.colors.multipleItemsSelectedCircleColor ?? YPConfig.colors.tintColor
        if v.showDraftImages{
            cell.imageView.image = v.draftItem[indexPath.row].image
            cell.multipleSelectionIndicator.isHidden = !multipleSelectionEnabled
            
            cell.isSelected = currentlySelectedIndex == indexPath.row
            
            // Set correct selection number
            if let index = selection.firstIndex(where: { $0.index == indexPath.row }) {
                let currentSelection = selection[index]
                if currentSelection.index < 0 {
                    selection[index] = YPLibrarySelection(index: indexPath.row,
                                                          cropRect: currentSelection.cropRect,
                                                           scrollViewContentOffset: currentSelection.scrollViewContentOffset,
                                                          scrollViewZoomScale: currentSelection.scrollViewZoomScale,
                                                          assetIdentifier: currentSelection.assetIdentifier
                                                          )
                }
                cell.multipleSelectionIndicator.set(number: index + 1) // start at 1, not 0
            } else {
                cell.multipleSelectionIndicator.set(number: nil)
            }
        }else{
            let asset = mediaManager.fetchResult[indexPath.row]
            cell.representedAssetIdentifier = asset.localIdentifier
        mediaManager.imageManager?.requestImage(for: asset,
                                   targetSize: v.cellSize(),
                                   contentMode: .aspectFill,
                                   options: nil) { image, _ in
                                    // The cell may have been recycled when the time this gets called
                                    // set image only if it's still showing the same asset.
                                    if cell.representedAssetIdentifier == asset.localIdentifier && image != nil {
                                        cell.imageView.image = image
                                    }

            }
   
        let isVideo = (asset.mediaType == .video)
        cell.durationLabel.isHidden = !isVideo
        cell.durationLabel.text = isVideo ? YPHelper.formattedStrigFrom(asset.duration) : ""
        cell.multipleSelectionIndicator.isHidden = !multipleSelectionEnabled
        cell.isSelected = currentlySelectedIndex == indexPath.row
        
        // Set correct selection number
        if let index = selection.firstIndex(where: { $0.assetIdentifier == asset.localIdentifier }) {
            let currentSelection = selection[index]
            if currentSelection.index < 0 {
                selection[index] = YPLibrarySelection(index: indexPath.row,
                                                      cropRect: currentSelection.cropRect,
                                                      scrollViewContentOffset: currentSelection.scrollViewContentOffset,
                                                      scrollViewZoomScale: currentSelection.scrollViewZoomScale,
                                                      assetIdentifier: currentSelection.assetIdentifier,
                                                      croppedImage: currentSelection.croppedImage)
            }
            cell.multipleSelectionIndicator.set(number: index + 1) // start at 1, not 0
        } else {
            cell.multipleSelectionIndicator.set(number: nil)
            if  multipleSelectionEnabled && selection.count < 1
              {
                multipleSelectioTapped()
              }
        }
        }
        // Prevent weird animation where thumbnail fills cell on first scrolls.
        UIView.performWithoutAnimation {
            cell.layoutIfNeeded()
        }
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previouslySelectedIndexPath = IndexPath(row: currentlySelectedIndex, section: 0)
        currentlySelectedIndex = indexPath.row
        if v.showDraftImages{
            self.singleImage = v.draftItem[indexPath.row].image
            self.selectedDraftItem = v.draftItem[indexPath.row]
            changeAssetDraft(v.draftItem[indexPath.row].image)
        }else{
            if previouslySelectedIndexPath != indexPath {
               changeAsset(mediaManager.fetchResult[indexPath.row])
            }
        }
        panGestureHelper.resetToOriginalState()
        
        // Only scroll cell to top if preview is hidden.
        if !panGestureHelper.isImageShown {
            collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
        }
        v.refreshImageCurtainAlpha()
            
        if multipleSelectionEnabled {
            let cellIsInTheSelectionPool = isInSelectionPool(indexPath: indexPath)
            let cellIsCurrentlySelected = previouslySelectedIndexPath.row == currentlySelectedIndex
            if cellIsInTheSelectionPool {
                if cellIsCurrentlySelected {
                    deselect(indexPath: indexPath)
                }
            } else if isLimitExceeded == false {
                addToSelection(indexPath: indexPath)
            }
            collectionView.reloadItems(at: [indexPath])
            collectionView.reloadItems(at: [previouslySelectedIndexPath])
        } else {
            selection.removeAll()
            addToSelection(indexPath: indexPath)
            
            // Force deseletion of previously selected cell.
            // In the case where the previous cell was loaded from iCloud, a new image was fetched
            // which triggered photoLibraryDidChange() and reloadItems() which breaks selection.
            //
            if let previousCell = collectionView.cellForItem(at: previouslySelectedIndexPath) as? YPLibraryViewCell {
                previousCell.isSelected = false
            }
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return isProcessing == false
    }
    
    public func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return isProcessing == false
    }
}

extension YPLibraryVC: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {
        let margins = YPConfig.library.spacingBetweenItems * CGFloat(YPConfig.library.numberOfItemsInRow - 1)
        let width = (collectionView.frame.width - margins) / CGFloat(YPConfig.library.numberOfItemsInRow)
        return CGSize(width: width, height: width)
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return YPConfig.library.spacingBetweenItems
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return YPConfig.library.spacingBetweenItems
    }
}
