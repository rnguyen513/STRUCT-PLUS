//
//  SlidersView.swift
//  ARKitRectangleDetection
//
//  Created by ISEE Lab on 4/16/24.
//  Copyright © 2024 Mel Ludowise. All rights reserved.
//

import Foundation
import SwiftUI

struct SlidersView: View {
    @ObservedObject var sliderValues: SliderValues
    @State private var isDropdownOpen: Bool = false
    var onValueChange: (SliderValues) -> Void
    
    var body: some View {
        Form {
            DisclosureGroup("Adjust Model Inputs", isExpanded: $isDropdownOpen) {
                //VStack(alignment: .leading) {
                    Text("X Input: \(self.sliderValues.xValue, specifier: "%.1f")")
                    Slider(value: Binding(get: {
                        self.sliderValues.xValue
                    }, set: { (newValue) in
                        self.sliderValues.xValue = newValue
                        onValueChange(self.sliderValues)
                        //print("@SLIDERSVIEW: X", newValue)
                    }), in: -200...200, step: 5.0)
                    
                    Text("Y Input: \(self.sliderValues.yValue, specifier: "%.1f")")
                    Slider(value: Binding(get: {
                        self.sliderValues.yValue
                    }, set: { (newValue) in
                        self.sliderValues.yValue = newValue
                        onValueChange(self.sliderValues)
                        //print("@SLIDERSVIEW: Y", newValue)
                    }), in: -200...200, step: 5.0)
                //}
                //.padding()
            }
            .navigationBarTitle("Inputs", displayMode: .inline)
            .background(Color.clear)
        }
    }
}

class SliderValues: ObservableObject {
    @Published var xValue: Float = 0.0
    @Published var yValue: Float = 0.0
}
