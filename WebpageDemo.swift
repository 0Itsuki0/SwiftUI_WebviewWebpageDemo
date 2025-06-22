//
//  WebpageDemo.swift
//  Beta26Demo
//
//  Created by Itsuki on 2025/06/22.
//

import SwiftUI
import WebKit

import UniformTypeIdentifiers

// MARK: Demo on using webpage for full control
struct WebPageDemo: View {
    private let baseURL: URL? = URL(string: "https://medium.com/@itsuki.enjoy")

    @State private var page: WebPage?
    
    private var navigationDecider: NavigationDecider = .init()
    @State private var openURL: URL? = nil

    private var dialogPresenter: DialogPresenter = .init()
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    
    @State private var scrollPosition: ScrollPosition = ScrollPosition()
    @State private var showScrollToTop: Bool = false
    @State private var showDescription: Bool = false
    
    @State private var description: String? = nil
    
    @State private var htmlImage: Image? = nil
    @State private var htmlPDF: Data? = nil
    
    private struct PageChange: Equatable {
        var id: WebPage.NavigationID?
        var url: URL?
    }
    
    private let datastore: WKWebsiteDataStore = .nonPersistent()

    
    var body: some View {
        NavigationStack {

            if let page {
                let pageChange = PageChange(id: page.currentNavigationEvent?.navigationID, url: page.url)
                
                WebView(page)
                    .navigationTitle(page.title)
                    .alert("Oops", isPresented: $showAlert, actions: {
                        Button(action: {
                            showAlert = false
                        }, label: {
                            Text("OK")
                        })
                    }, message: {
                        if let alertMessage {
                            Text(alertMessage)
                        }
                    })
                    .onChange(of: alertMessage, {
                        if alertMessage != nil {
                            self.showAlert = true
                        }
                    })
                    .onChange(of: showAlert, {
                        if !showAlert {
                            self.alertMessage = nil
                        }
                    })
                    .onChange(of: openURL, {
                        if let openURL = openURL {
                            UIApplication.shared.open(openURL)
                            self.openURL = nil
                        }
                    })
                    .onChange(of: pageChange, initial: true, {
                        guard page.currentNavigationEvent?.navigationID != nil else { return }
                        
                        Task {
                            await self.injectBackgroundColorJS(to: page)
                        }
                        Task {
                            self.description = await self.getPageDescription(page)
                        }
                        
                    })
                    .overlay(content: {
                        if page.isLoading {
                            ProgressView()
                                .controlSize(.large)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.yellow.opacity(0.1))
                        }
                    })
                    .webViewBackForwardNavigationGestures(.disabled)
                    .webViewScrollPosition($scrollPosition)
                    .defaultScrollAnchor(.top, for: .alignment)
                    .toolbar(content: {
                        ToolbarItem(placement: .topBarTrailing, content: {
                            
                            Menu(content: {
                                ShareLink(
                                    item: AsyncPDFTransferable(generatePDF: {
                                        try? await page.pdf(configuration: .init())
                                    }),
                                    subject: Text("PDF"),
                                    message: Text("Save HTML as PDF"),
                                    preview: SharePreview(
                                        page.title,
                                        image: AsyncPDFTransferable(generatePDF: {
                                            try? await page.pdf(configuration: .init())
                                        }),
                                    ), label: {
                                        HStack {
                                            Text("Share PDF")
                                            Image(systemName: "document")
                                        }
                                    }
                                )
                                
                                ShareLink(
                                    item: AsyncImageTransferable(generateImage: {
                                        try? await page.snapshot(.init())
                                    }),
                                    subject: Text("Image"),
                                    message: Text("Save HTML as Image"),
                                    preview: SharePreview(
                                        page.title,
                                        image: AsyncImageTransferable(generateImage: {
                                            try? await page.snapshot(.init())
                                        }),
                                    ), label: {
                                        HStack {
                                            Text("Share Image")
                                            Image(systemName: "photo")
                                        }
                                    }
                                )

                            }, label: {
                                Image(systemName: "square.and.arrow.up")
                            })
                            

                        })

                        
                        ToolbarItem(placement: .topBarTrailing, content: {
                            if showScrollToTop {
                                Button(action: {
                                    scrollPosition.scrollTo(edge: .top)
                                }, label: {
                                    Text("Top")
                                })
                            }
                        })
                        
                        ToolbarItem(placement: .topBarTrailing, content: {
                            if let description {
                                Button(action: {
                                    showDescription = true
                                }, label: {
                                    Text("Description")
                                })
                                .popover(isPresented: $showDescription, content: {
                                    Text(description)
                                        .presentationCompactAdaptation(.popover)
                                    
                                })
                            }
                        })
    
                    })
                    .safeAreaInset(edge: .bottom, alignment: .leading, content: {
                        
                        HStack(spacing: 0) {
                            Button(action: {
                                if let last = page.backForwardList.backList.last {
                                    page.load(last)
                                }
                            }, label: {
                                Image(systemName: "chevron.backward")
                                    .padding()
                            })
                            .disabled(page.backForwardList.backList.isEmpty)
                            
                            Divider()
                                .frame(height: 32)
                                .padding(.vertical, 4)
                            
                            Button(action: {
                                if let first = page.backForwardList.forwardList.first {
                                    page.load(first)
                                }
                            }, label: {
                                Image(systemName: "chevron.forward")
                                    .padding()
                            })
                            .disabled(page.backForwardList.forwardList.isEmpty)

                        }
                        .background(
                            Capsule()
                                .fill(.white)
                                .stroke(.black.opacity(0.2), style: .init())
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 2, y: 2)
                        )
                        .padding(.leading, 24)

                        
                    })
                    .webViewOnScrollGeometryChange(for: CGFloat.self, of: { geometry in
                        return geometry.contentOffset.y
                    }, action: { old, new in
                        showScrollToTop = new > 0
                    })
                

            }
        }
        .onAppear {
            initWebpage()
            loadInitialContents()
        }

    }
    
    private func initWebpage() {
        
        // configuration
        var configuration = WebPage.Configuration()

        var navigationPreference = WebPage.NavigationPreferences()
        
        navigationPreference.allowsContentJavaScript = true
        navigationPreference.preferredHTTPSNavigationPolicy = .keepAsRequested
        navigationPreference.preferredContentMode = .mobile
        configuration.defaultNavigationPreferences = navigationPreference
        
        configuration.websiteDataStore = self.datastore
        
        configuration.applicationNameForUserAgent = "Itsuki's Webview"
        
        self.navigationDecider.url = self.baseURL
        self.navigationDecider.setOpenURL = { url in self.openURL = url }
        
        self.dialogPresenter.setAlertMessage = { string in self.alertMessage = string }

        let page = WebPage(configuration: configuration, navigationDecider: self.navigationDecider, dialogPresenter: self.dialogPresenter)
        
        page.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36"

        self.page = page
        
    }
    
    private func getCookies() async -> [HTTPCookie] {
        let cookies = await self.datastore.httpCookieStore.allCookies()
        return cookies
    }
    
    private func setCookies(_ cookie: HTTPCookie) {
        self.datastore.httpCookieStore.setCookie(cookie)
    }
    
    private func loadInitialContents() {
        guard let url = self.baseURL else {
            return
        }
        page?.load(URLRequest(url: url))
    }
    
    private func injectBackgroundColorJS(to page: WebPage) async {
        let css = """
        body, main, div {
          background-color: rgba(255, 255, 191) !important;
        }
        """
        let cssString = css.components(separatedBy: .newlines).joined()

        let script = """
                        var element = document.createElement('style');
                           element.innerHTML = '\(cssString)';
                           document.head.appendChild(element);
                     """

        do {
           try await page.callJavaScript(script)
        } catch (let error) {
            print("error calling JS: ", error)
        }
        
    }
    
    private func getPageDescription(_ page: WebPage) async -> String? {
        let fetchOpenGraphProperty = """
            const propertyValues = document.querySelector(`meta[name="${name}"]`);
            if (propertyValues !== null) {
                return propertyValues.content;
            } else {
                return null
            }
            
        """

        let arguments: [String: String] = [
            "name": "description"
        ]
        
        do {
            let description = try await page.callJavaScript(fetchOpenGraphProperty, arguments: arguments) as? String
            return description
        } catch (let error) {
            print("error calling JS: ", error)
        }

        return nil
    }

}


private class NavigationDecider: WebPage.NavigationDeciding {
    var setOpenURL: ((URL?) -> Void)?
    var url: URL?

    
    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        // checking this because some web pages call google captcha in subframe
        if action.target != nil && action.target?.isMainFrame == false {
            return .allow
        }

        let requestURL = action.request.url
        if requestURL?.host() == self.url?.host() {
            return .allow
        }
        self.setOpenURL?(requestURL)
        return .cancel
    }
}

private class DialogPresenter: WebPage.DialogPresenting {
    var setAlertMessage: ((String) -> Void)?
    func handleJavaScriptAlert(message: String, initiatedBy frame: WebPage.FrameInfo) async {
        self.setAlertMessage?(message)
    }
}


nonisolated private struct AsyncPDFTransferable: Transferable {
    var generatePDF: () async -> Data?

    enum Error: Swift.Error {
        case getPDFDataFailed
    }
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { item in
            guard let data = await item.generatePDF() else {
                throw Error.getPDFDataFailed
            }
            return data
        }
    }
}


nonisolated private struct AsyncImageTransferable: Transferable {
    var generateImage: () async -> Image?

    enum Error: Swift.Error {
        case getImageDataFailed
    }
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .image) { item in
            guard let image = await item.generateImage(), let data = await image.dataRepresentation else {
                throw Error.getImageDataFailed
            }
            return data
        }
    }
}

extension Image {
    var dataRepresentation: Data? {
        let renderer = ImageRenderer(content: self)
        return renderer.uiImage?.pngData()
    }
}

