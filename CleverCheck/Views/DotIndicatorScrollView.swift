//
//  DotIndicatorScrollView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 03/02/2026.
//

import SwiftUI

struct DotIndicatorScrollView: View {
    // Use type-erased views and drive ForEach by indices to avoid Hashable conformance issues
    let tabViews: [AnyView]
    @State private var currentStep = 0
    
    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $currentStep.animation()) {
                ForEach(tabViews.indices, id: \.self) { index in
                    tabViews[index]
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Dots indicator matching the number of tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabViews.indices, id: \.self) { index in
                        Circle()
                            .frame(width: index == currentStep ? 12 : 8,
                                   height: index == currentStep ? 12 : 8)
                            .foregroundStyle(.blue.opacity(index == currentStep ? 1 : 0.5))
                    }
                }
                .padding()
                .scrollTargetLayout()
            }
            .background(.clear, in: RoundedRectangle(cornerRadius: 30))
            .frame(maxWidth: 60)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding($currentStep), anchor: .center)
            .allowsTightening(false)
        }
    }
}

// Convenience initializer to accept heterogeneous views without forcing callers to wrap to AnyView
extension DotIndicatorScrollView {
    init<V: View>(tabViews: [V]) {
        self.tabViews = tabViews.map { AnyView($0) }
    }
}
