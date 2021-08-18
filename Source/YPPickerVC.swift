//
//  YYPPickerVC.swift
//  YPPickerVC
//
//  Created by Sacha Durand Saint Omer on 25/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import UIKit
import Stevia
import Photos

protocol ImagePickerDelegate: AnyObject {
    func noPhotos()
    func shouldAddToSelection(indexPath: IndexPath, numSelections: Int) -> Bool
}

open class YPPickerVC: YPBottomPager, YPBottomPagerDelegate {
    
    let albumsManager = YPAlbumsManager()
    var shouldHideStatusBar = false
    var initialStatusBarHidden = false
    weak var imagePickerDelegate: ImagePickerDelegate?
    
    override open var prefersStatusBarHidden: Bool {
        return (shouldHideStatusBar || initialStatusBarHidden) && YPConfig.hidesStatusBar
    }
    
    /// Private callbacks to YPImagePicker
    public var didClose:(() -> Void)?
    public var didSelectItems: (([YPMediaItem]) -> Void)?
    public var didSelectDraftItems: (([UIImage]) -> Void)?
    
    enum Mode {
        case library
        case camera
        case video
    }
    
    public var libraryVC: YPLibraryVC?
    private var cameraVC: YPCameraVC?
    private var videoVC: YPVideoCaptureVC?
    
    var mode = Mode.camera
    
    var capturedImage: UIImage?
    
    open override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = YPConfig.colors.safeAreaBackgroundColor
        
        delegate = self
        
        // Force Library only when using `minNumberOfItems`.
        if YPConfig.library.minNumberOfItems > 1 {
            YPImagePickerConfiguration.shared.screens = [.library]
        }
        
        // Library
        if YPConfig.screens.contains(.library) {
            libraryVC = YPLibraryVC()
            libraryVC?.delegate = self
        }
        
        // Camera
        if YPConfig.screens.contains(.photo) {
            cameraVC = YPCameraVC()
            cameraVC?.didCapturePhoto = { [weak self] img in
                self?.didSelectItems?([YPMediaItem.photo(p: YPMediaPhoto(image: img,
                                                                        fromCamera: true))])
            }
        }
        
        // Camera
        if YPConfig.screens.contains(.library) {
            libraryVC = YPLibraryVC()
            libraryVC?.didCapturePhoto = { [weak self] img in
                self?.didSelectItems?([YPMediaItem.photo(p: YPMediaPhoto(image: img,
                                                                        fromCamera: true))])
            }
        }
        
        // Video
        if YPConfig.screens.contains(.video) {
            videoVC = YPVideoCaptureVC()
            videoVC?.didCaptureVideo = { [weak self] videoURL in
                self?.didSelectItems?([YPMediaItem
                    .video(v: YPMediaVideo(thumbnail: thumbnailFromVideoPath(videoURL),
                                           videoURL: videoURL,
                                           fromCamera: true))])
            }
        }
        
        // Show screens
        var vcs = [UIViewController]()
        for screen in YPConfig.screens {
            switch screen {
            case .library:
                if let libraryVC = libraryVC {
                    vcs.append(libraryVC)
                }
            case .photo:
                if let cameraVC = cameraVC {
                    vcs.append(cameraVC)
                }
            case .video:
                if let videoVC = videoVC {
                    vcs.append(videoVC)
                }
            }
        }
        controllers = vcs
        
        // Select good mode
        if YPConfig.screens.contains(YPConfig.startOnScreen) {
            switch YPConfig.startOnScreen {
            case .library:
                mode = .library
            case .photo:
                mode = .camera
            case .video:
                mode = .video
            }
        }
        
        // Select good screen
        if let index = YPConfig.screens.firstIndex(of: YPConfig.startOnScreen) {
            startOnPage(index)
        }
        
        YPHelper.changeBackButtonIcon(self)
        YPHelper.changeBackButtonTitle(self)
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraVC?.v.shotButton.isEnabled = true
        libraryVC?.v.forwardbutton.addTarget(self, action: #selector(done), for: .touchUpInside)
        updateMode(with: currentController)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shouldHideStatusBar = true
        initialStatusBarHidden = true
        UIView.animate(withDuration: 0.3) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    internal func pagerScrollViewDidScroll(_ scrollView: UIScrollView) { }
    
    func modeFor(vc: UIViewController) -> Mode {
        switch vc {
        case is YPLibraryVC:
            return .library
        case is YPCameraVC:
            return .camera
        case is YPVideoCaptureVC:
            return .video
        default:
            return .camera
        }
    }
    
    func pagerDidSelectController(_ vc: UIViewController) {
        updateMode(with: vc)
    }
    
    func updateMode(with vc: UIViewController) {
        stopCurrentCamera()
        
        // Set new mode
        mode = modeFor(vc: vc)
        
        // Re-trigger permission check
        if let vc = vc as? YPLibraryVC {
            vc.checkPermission()
        } else if let cameraVC = vc as? YPCameraVC {
            cameraVC.start()
        } else if let videoVC = vc as? YPVideoCaptureVC {
            videoVC.start()
        }
    
        updateUI()
    }
    
    func stopCurrentCamera() {
        switch mode {
        case .library:
            libraryVC?.pausePlayer()
        case .camera:
            cameraVC?.stopCamera()
        case .video:
            videoVC?.stopCamera()
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        shouldHideStatusBar = false
        stopAll()
    }
    
    @objc
    func navBarTapped() {
        let vc = YPAlbumVC(albumsManager: albumsManager)
        let navVC = UINavigationController(rootViewController: vc)
        navVC.navigationBar.tintColor = .ypLabel
        
        vc.didSelectAlbum = { [weak self] album in
            self?.libraryVC?.setAlbum(album)
            self?.setTitleViewWithTitle(aTitle: album.title)
            navVC.dismiss(animated: true, completion: nil)
        }
        present(navVC, animated: true, completion: nil)
    }
    
    func setTitleViewWithTitle(aTitle: String) {
        let titleView = UIView()
        titleView.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        
        let label = UILabel()
        label.text = aTitle
        // Use YPConfig font
        label.font = YPConfig.fonts.pickerTitleFont

        // Use custom textColor if set by user.
        if let navBarTitleColor = UINavigationBar.appearance().titleTextAttributes?[.foregroundColor] as? UIColor {
            label.textColor = navBarTitleColor
        }
        
        if YPConfig.library.options != nil {
            titleView.sv(
                label
            )
            |-(>=8)-label.centerHorizontally()-(>=8)-|
            align(horizontally: label)
        } else {
            let arrow = UIImageView()
            arrow.image = YPConfig.icons.arrowDownIcon
            arrow.image = arrow.image?.withRenderingMode(.alwaysTemplate)
            arrow.tintColor = .ypLabel
            
            let attributes = UINavigationBar.appearance().titleTextAttributes
            if let attributes = attributes, let foregroundColor = attributes[.foregroundColor] as? UIColor {
                arrow.image = arrow.image?.withRenderingMode(.alwaysTemplate)
                arrow.tintColor = foregroundColor
            }
            
            let button = UIButton()
            button.addTarget(self, action: #selector(navBarTapped), for: .touchUpInside)
            button.setBackgroundColor(UIColor.white.withAlphaComponent(0.5), forState: .highlighted)
            
            titleView.sv(
                label,
                arrow,
                button
            )
            button.fillContainer()
            |-(>=8)-label.centerHorizontally()-arrow-(>=8)-|
            align(horizontally: label-arrow)
        }
        
        label.firstBaselineAnchor.constraint(equalTo: titleView.bottomAnchor, constant: -14).isActive = true
        
        titleView.heightAnchor.constraint(equalToConstant: 40).isActive = true
       // navigationItem.titleView = titleView
    }
 
    func updateUI() {
        if !YPConfig.hidesCancelButton {
            // Update Nav Bar state.arrowtriangle.left.fill
            self.addBackButtonItem(title:YPConfig.wordings.cancel, saveAsDraft: false, isFromcrop: false)
        }
        switch mode {
        case .library:
            setTitleViewWithTitle(aTitle: libraryVC?.title ?? "")
           // navigationItem.rightBarButtonItem = UIBarButtonItem(title: YPConfig.wordings.next,
//                                                                style: .done,
//                                                                target: self,
//                                                                action: #selector(done))
         //   navigationItem.rightBarButtonItem?.tintColor = YPConfig.colors.tintColor
            navigationItem.rightBarButtonItem = nil
            // Disable Next Button until minNumberOfItems is reached.
          //  navigationItem.rightBarButtonItem?.isEnabled =
           //     libraryVC!.selection.count >= YPConfig.library.minNumberOfItems

        case .camera:
            navigationItem.titleView = nil
            title = cameraVC?.title
            navigationItem.rightBarButtonItem = nil
        case .video:
            navigationItem.titleView = nil
            title = videoVC?.title
            navigationItem.rightBarButtonItem = nil
        }

        navigationItem.rightBarButtonItem?.setFont(font: YPConfig.fonts.rightBarButtonFont, forState: .normal)
        navigationItem.rightBarButtonItem?.setFont(font: YPConfig.fonts.rightBarButtonFont, forState: .disabled)
        navigationItem.leftBarButtonItem?.setFont(font: YPConfig.fonts.leftBarButtonFont, forState: .normal)
        self.navigationController!.navigationBar.shadowImage = UIImage()
        self.navigationController!.navigationBar.isTranslucent = false
        self.navigationController!.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.compact)
    }
    
    @objc func openCamera(){
        cameraVC?.start()
    }
    
    @objc
    func close() {
        // Cancelling exporting of all videos
        if let libraryVC = libraryVC {
            libraryVC.mediaManager.forseCancelExporting()
        }
        self.didClose?()
    }
    
    // When pressing "Next"
    @objc
    func done() {
        libraryVC?.fromCropClick = false
        guard let libraryVC = libraryVC else { print("⚠️ YPPickerVC >>> YPLibraryVC deallocated"); return }
            if mode == .library {
                libraryVC.doAfterPermissionCheck { [weak self] in
                    if libraryVC.v.showDraftImages{
                        let selectedDraft = libraryVC.selectDraftMedia()
                        self?.didSelectDraftItems?(selectedDraft)
                    }else{
                        libraryVC.selectedMedia(photoCallback: { photo in
                            self?.didSelectItems?([YPMediaItem.photo(p: photo)])
                        }, videoCallback: { video in
                            self?.didSelectItems?([YPMediaItem
                                .video(v: video)])
                        }, multipleItemsCallback: { items in
                            self?.didSelectItems?(items)
                        })
                    }
                }
            }
    }
    
    @objc
    func crop() {
        libraryVC?.fromCropClick = true
        guard let libraryVC = libraryVC else { print("⚠️ YPPickerVC >>> YPLibraryVC deallocated"); return }
            if mode == .library {
                libraryVC.doAfterPermissionCheck { [weak self] in
                    libraryVC.selectedMedia(photoCallback: { photo in
                        self?.didSelectItems?([YPMediaItem.photo(p: photo)])
                    }, videoCallback: { video in
                        self?.didSelectItems?([YPMediaItem
                            .video(v: video)])
                    }, multipleItemsCallback: { items in
                        self?.didSelectItems?(items)
                    })
                }
            }
    }
    
    func stopAll() {
        libraryVC?.v.assetZoomableView.videoView.deallocate()
        videoVC?.stopCamera()
        cameraVC?.stopCamera()
    }
}

extension YPPickerVC: YPLibraryViewDelegate {

    public func libraryViewDidTapNext() {
        libraryVC?.isProcessing = true
        DispatchQueue.main.async {
            self.v.scrollView.isScrollEnabled = false
            self.libraryVC?.v.fadeInLoader()
            self.navigationItem.rightBarButtonItem = YPLoaders.defaultLoader
        }
    }
    
    public func libraryViewStartedLoadingImage() {
        //TODO remove to enable changing selection while loading but needs cancelling previous image requests.
        libraryVC?.isProcessing = true
        DispatchQueue.main.async {
            self.libraryVC?.v.fadeInLoader()
        }
    }
    
    public func libraryViewFinishedLoading() {
        libraryVC?.isProcessing = false
        DispatchQueue.main.async {
            self.v.scrollView.isScrollEnabled = YPConfig.isScrollToChangeModesEnabled
            self.libraryVC?.v.hideLoader()
            self.updateUI()
        }
    }
    
    override func backButtonClick(sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    public func libraryViewDidToggleMultipleSelection(enabled: Bool) {
        var offset = v.header.frame.height
        if #available(iOS 11.0, *) {
            offset += v.safeAreaInsets.bottom
        }
        
        v.header.bottomConstraint?.constant = enabled ? offset : 0
        v.layoutIfNeeded()
        updateUI()
    }
    
    public func noPhotosForOptions() {
        self.dismiss(animated: true) {
            self.imagePickerDelegate?.noPhotos()
        }
    }
    
    public func libraryViewShouldAddToSelection(indexPath: IndexPath, numSelections: Int) -> Bool {
        return imagePickerDelegate?.shouldAddToSelection(indexPath: indexPath, numSelections: numSelections) ?? true
    }
}
extension UIViewController {

    func addBackButtonItem(title:String,saveAsDraft:Bool,isFromcrop:Bool) {
        navigationController?.isNavigationBarHidden = false
        let backMenu: UIButton = UIButton()
        backMenu.setImage(YPConfig.icons.backButtonIcon, for: .normal)
        backMenu.setTitle(title, for: .normal)
        backMenu.sizeToFit()
        backMenu.contentHorizontalAlignment = .left
        backMenu.tintColor = .black
        backMenu.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        backMenu.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        backMenu.setTitleColor(.black, for: .normal)
        backMenu.titleLabel?.font = YPConfig.fonts.leftBarButtonFont
        backMenu.titleLabel!.textColor = .black
        if isFromcrop{
            backMenu.addTarget(self, action: #selector (backAlertButtonClick), for: .touchUpInside)
        }else{
            backMenu.addTarget(self, action: #selector (backButtonClick(sender:)), for: .touchUpInside)
        }
        let barButton = UIBarButtonItem(customView: backMenu)
        if(saveAsDraft){
            addSaveAsDraftButton()
        }
        self.navigationItem.leftBarButtonItem = barButton
        self.navigationController?.navigationBar.tintColor = .black
        self.navigationController?.navigationBar.backgroundColor = .white
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.compact)
    }
    
    func addSaveAsDraftButton(){
        let saveDraftMenu: UIButton = UIButton()
        let image = YPConfig.icons.saveAsDratButtonIcon;
        saveDraftMenu.setImage(image, for: .normal)
        saveDraftMenu.setTitle("Save as draft", for: .normal);
        saveDraftMenu.width(150)
        saveDraftMenu.contentHorizontalAlignment = .right
        saveDraftMenu.tintColor = YPConfig.colors.tintColor
        saveDraftMenu.imageEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 0, right: 15)
        saveDraftMenu.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9)
        saveDraftMenu.setTitleColor(YPConfig.colors.tintColor, for: .normal)
        saveDraftMenu.titleLabel?.font = YPConfig.fonts.saveAsDraftFont
        saveDraftMenu.titleLabel!.textColor = YPConfig.colors.tintColor
        saveDraftMenu.addTarget(self, action: #selector (saveAsDraftClick(sender:)), for: .touchUpInside)
        let barButton = UIBarButtonItem(customView: saveDraftMenu)
        self.navigationItem.rightBarButtonItem = barButton
    }

    @objc func backAlertButtonClick(){
        let alert = UIAlertController(title: "Discard changes", message: "You will loose all the edits performed", preferredStyle: .actionSheet)
          alert.addAction(UIAlertAction(title: "Discard", style: .destructive , handler:{ (UIAlertAction)in
            self.dismiss(animated: true, completion: nil)
            self.navigationController?.popViewController(animated: true);
          }))
          
          alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler:{ (UIAlertAction)in
            self.dismiss(animated: true, completion: nil)
          }))
          self.present(alert, animated: true, completion: {
              print("completion block")
          })
    }
    
    @objc func backButtonClick(sender : UIButton) {
            self.navigationController?.popViewController(animated: true);
    }
    @objc func saveAsDraftClick(sender : UIButton) {
        //action
    }
    
    
}
