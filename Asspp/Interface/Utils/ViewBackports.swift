//
//  ViewBackports.swift
//  Asspp
//
//  Created by luca on 19.09.2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func mediumAndLargeDetents() -> some View {
        #if os(iOS)
            if #available(iOS 16.0, *) {
                presentationDetents([.medium, .large])
            } else {
                self
            }
        #else
            self
        #endif
    }

    /// `onChange(of:perform:)` was replaced by a closure taking both old and new
    /// values in iOS 17; this keeps one call shape usable from iOS 15 upward.
    @ViewBuilder
    func onChangeCompact<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        perform action: @escaping (Value) -> Void,
    ) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            onChange(of: value, initial: initial) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }

    @ViewBuilder
    func neverMinimizeTab() -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                tabBarMinimizeBehavior(.never)
            } else {
                self
            }
        #else
            self
        #endif
    }

    @ViewBuilder
    func activateSearchWhenSearchTabSelected() -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                tabViewSearchActivation(.searchTabSelection)
            } else {
                self
            }
        #else
            self
        #endif
    }

    @ViewBuilder
    func sidebarAdaptableTabView() -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                tabViewStyle(.sidebarAdaptable)
            } else {
                self
            }
        #else
            self
        #endif
    }

    @ViewBuilder
    func smallControlSizeOnMac() -> some View {
        #if os(macOS)
            controlSize(.small)
        #else
            self
        #endif
    }

    @ViewBuilder
    func hide() -> some View {}

    /// Wraps content in the platform's navigation root. `NavigationStack`
    /// replaced `NavigationView` in iOS 16, which iOS 15 does not have.
    @ViewBuilder
    func inNavigationRoot() -> some View {
        #if os(macOS)
            NavigationStack { self }
        #else
            if #available(iOS 16.0, *) {
                NavigationStack { self }
            } else {
                NavigationView { self }
                    .navigationViewStyle(.stack)
            }
        #endif
    }

    /// `formStyle` is iOS 16; an iOS 15 `Form` already renders grouped.
    @ViewBuilder
    func groupedFormStyle() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            formStyle(.grouped)
        } else {
            self
        }
    }
}

extension Animation {
    /// The parameterless `Animation.spring` is iOS 17; this is the same curve
    /// expressed through the initializer available since iOS 13.
    static var springDefault: Animation {
        .spring(response: 0.55, dampingFraction: 0.825, blendDuration: 0)
    }

    static var interactiveSpringDefault: Animation {
        .interactiveSpring(response: 0.15, dampingFraction: 0.8625, blendDuration: 0)
    }
}

public extension ToolbarContent {
    /// Choosing between toolbar contents needs `buildEither`, which is iOS 16;
    /// the only caller is macOS-only.
    @available(iOS 16.0, *)
    @ToolbarContentBuilder
    nonisolated func hideSharedBackground() -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
