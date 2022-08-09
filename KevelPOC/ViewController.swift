//
//  ViewController.swift
//  KevelPOC
//
//  Created by Luis Francisco Dzuryk on 09/08/2022.
//

import UIKit
import WebKit
import AdzerkSDK

class ViewController: UIViewController {
    @IBOutlet weak var webKit: WKWebView!
    @IBOutlet weak var eventsTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        webKit.navigationDelegate = self
    }

    @IBAction func fetchAd(_ sender: Any) {
        let client = DecisionSDK()

        let placement = Placements.custom(divName: "div0", adTypes: [4585])

//        var reqOpts = PlacementRequest<StandardPlacement>.Options()
//        reqOpts.userKey = "abc"
//        reqOpts.keywords = ["keyword1", "keyword2"]

//        client.request(placements: [p], options: reqOpts) {response in
//          dump(response)
//        }
        client.request(placement: placement) { result in
        switch result {
        case .success(let response):
            dump(response)
            if let htmlContent = response.decisions["div0"]?[0].contents[0].body {
                print(htmlContent)
                self.webKit.loadHTMLString(htmlContent, baseURL: Bundle.main.bundleURL)
            }
        case .failure(let error):
            dump(error)
        }
        }
    }
}

//MARK: WKNavigationDelegate implementation
extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.addEventListener(elementID: "master-card-banner__btn", callbackID: "banner_button_tapped", elementType: .class, handler: self, completion: nil)
        webView.addEventListener(elementID: "master-card-banner__subtitle master-card-banner__subtitle--mobile", callbackID: "see_detail", elementType: .class, handler: self, completion: nil)
    }
}

//MARK: WKScriptMessageHandler implementation
extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        eventsTextView.text.append("EVENT: \(message.name) \n")
    }
}

extension WKWebView {
    /// Type of HTML element to get from DOM
    enum ElementType {
        /// ID Element
        case id
        /// Class element
        case `class`
    }
    
    /// List of errors for WKWebView injection
    enum InjectionError: Error {
        /// The Listener is already added
        case listenerAlreadyAdded
    }
    
    /// Cahnges the CSS Visibiltiy
    /// - Parameters:
    ///   - elementID: The name of the element
    ///   - isVisible: Wether or not is visible
    ///   - elementType: The type of element to get
    ///   - completion: Callback triggered went script has been appended to WKWebView
    func changeCSSVisibility(elementID: String, isVisible: Bool, elementType: ElementType, completion: ((Error?)->Void)?) {
        let script: String
        
        switch elementType {
        case .id:
            script = "document.getElementById('\(elementID)').style.visibility = \(isVisible ? "'visible'":"'hidden'");"
        case .class:
        script =
            """
            [].forEach.call(document.querySelectorAll('.\(elementID)'), function (el) {
              el.style.visibility = \(isVisible ? "'visible'":"'hidden'");
            });
            """
        }
        
        evaluateJavaScript(script, completionHandler: { (result, error) in
            completion?(error)
        })
    }
    
    /// Adds a event listener that will be call on WKScriptMessageHandler - didReceiveMessage
    /// - Parameters:
    ///   - elementID: The name of the element
    ///   - callbackID: The ID for the callback
    ///   - elementType: The type of element to get
    ///   - completion: Callback triggered went script has been appended to WKWebView
    func addEventListener(elementID: String, callbackID: String, elementType: ElementType, handler: WKScriptMessageHandler, completion: ((Error?)->Void)?) {
        let element: String
        
        switch elementType {
        case .id:
            element = "document.getElementById('\(elementID)')"
        case .class:
            element = "document.getElementsByClassName('\(elementID)')[0]"
        }
        
        let scriptString = """
            function callback () {
                console.log('\(callbackID) clicked!')
                window.webkit.messageHandlers.\(callbackID).postMessage({
                    message: 'WKWebView-onClickListener-\(callbackID)'
                });
            }

            \(element).addEventListener('click', callback);
            """
        
        if configuration.userContentController.userScripts.first(where: { $0.source == scriptString }) == nil {
            evaluateJavaScript(scriptString) { [weak self] (result, error) -> Void in
                guard let self = self else { return }
                
                if let error = error {
                    completion?(error)
                } else {
                    self.configuration.userContentController.removeScriptMessageHandler(forName: callbackID)
                    self.configuration.userContentController.add(handler, name: callbackID)
                    self.configuration.userContentController.addUserScript(WKUserScript(source: scriptString, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
                }
            }
        } else {
            completion?(InjectionError.listenerAlreadyAdded)
        }
    }
}
