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
    
    private var decision: PlacementDecision?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        webKit.configuration.userContentController.add(self, name: "iOSBtnDetail")
        webKit.navigationDelegate = self
    }

    @IBAction func fetchAd(_ sender: Any) {
        let client = DecisionSDK()
        let placement = Placements.custom(divName: "div0", adTypes: [4585])

        client.request(placement: placement) { result in
            switch result {
            case .success(let response):
                if let htmlContent = response.decisions["div0"]?[0].contents[0].body {
                    self.decision = response.decisions["div0"]?[0]
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
        if let impressionUrl = decision?.impressionUrl {
            let client = DecisionSDK()
            client.recordImpression(pixelURL: impressionUrl)
        }
    }
}

//MARK: WKScriptMessageHandler implementation
extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let clickUrl = decision?.clickUrl {
            let client = DecisionSDK()
            client.firePixel(url: clickUrl) { result in
                switch result {
                case .success(let response):
                    dump(response)
                case .failure(let error):
                    dump(error)
                }
            }
        }
        eventsTextView.text.append("EVENT: \(message.name) \n")
    }
}
