//
//  Package.swift
//  YPImagePicker
//
//  Created by Malti Maurya on 14/08/21.
//  Copyright © 2021 Yummypets. All rights reserved.
//

import Package
let package = Package(
    dependencies: [
        .package(url: "https://github.com/HHK1/PryntTrimmerView.git", .upToNextMajor(from: "4.0.1"))
        .package(url: "https://github.com/freshOS/Stevia", .upToNextMajor(from: "4.7.3"))
        .package(url: "https://github.com/BinaryMalti/Brightroom.git",
            .revision("eb8e8b2c9c19e874ef6043dd8ad0cfacd975af2e"))
    ]
)
