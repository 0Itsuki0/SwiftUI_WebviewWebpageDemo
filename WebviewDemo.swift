//
//  WebviewDemo.swift
//  Beta26Demo
//
//  Created by Itsuki on 2025/06/21.
//

import SwiftUI
import WebKit


// MARK: Demo on using webview
struct WebviewDemo: View {
    @State private var url: URL? = URL(string: "https://medium.com/@itsuki.enjoy")
    @State private var scrollPosition: ScrollPosition = ScrollPosition()
    @State private var showScrollToTop: Bool = false
    @State private var showContentBackground = false
    
    var body: some View {
        NavigationStack {
            // from url
            WebView(url: url)
                .webViewScrollPosition($scrollPosition)
                .defaultScrollAnchor(.top, for: .alignment)
                .toolbar(content: {
                    if showScrollToTop {
                        Button(action: {
                            scrollPosition.scrollTo(edge: .top)
                        }, label: {
                            Text("Top")
                        })
                    }
                    Button(action: {
                        showContentBackground.toggle()
                    }, label: {
                        Text(showContentBackground ? "Hide" : "Show")
                    })
                })
                .webViewOnScrollGeometryChange(for: CGFloat.self, of: { geometry in
                    return geometry.contentOffset.y
                }, action: { old, new in
                    showScrollToTop = new > 0
                })
                // NOTE: probably should NOT disabled webViewBackForwardNavigationGestures.
                // Apple claims that [WebView](https://developer.apple.com/documentation/webkit/webview-swift.struct#Overview) get forward and backward buttons but they are not showing up.
                .webViewBackForwardNavigationGestures(.disabled)
                .webViewMagnificationGestures(.disabled)
                .webViewContentBackground(showContentBackground ? .visible : .hidden)
                .background(.yellow)
        }

    }
}

