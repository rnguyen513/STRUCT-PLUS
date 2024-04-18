//
//  Array+Extensions.swift
//  ARKitRectangleDetection
//
//  Created by ISEE Lab on 4/15/24.
//  Copyright © 2024 Mel Ludowise. All rights reserved.
//

import Foundation

extension Array {
    func safeIndex(_ index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
