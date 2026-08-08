import Observation
import SwiftUI
import WebKit

@MainActor
@Observable
final class WebBrowserModel: NSObject, WKNavigationDelegate {
    var addressText = "https://www.google.com"
    var pageTitle = "Find Online"
    var isLoading = false
    var canGoBack = false
    var canGoForward = false
    @ObservationIgnored weak var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        guard webView.url == nil else { return }
        navigate()
    }

    func navigate() {
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url: URL?
        if trimmed.contains(" ") || (!trimmed.contains(".") && !trimmed.contains(":")) {
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            url = components?.url
        } else if let direct = URL(string: trimmed), direct.scheme != nil {
            url = direct
        } else {
            url = URL(string: "https://\(trimmed)")
        }

        guard let url else { return }
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }

    func discoverImages() async throws -> [WebImageCandidate] {
        guard let webView else { return [] }
        let rawResult = try await webView.evaluateJavaScript(Self.discoveryScript)
        guard let dictionaries = rawResult as? [[String: Any]] else { return [] }

        let candidates = dictionaries.compactMap { dictionary -> WebImageCandidate? in
            guard
                let urlString = dictionary["url"] as? String,
                let url = URL(string: urlString)
            else { return nil }
            return WebImageCandidate(
                url: url,
                width: (dictionary["width"] as? NSNumber)?.intValue ?? 0,
                height: (dictionary["height"] as? NSNumber)?.intValue ?? 0,
                description: dictionary["description"] as? String ?? "",
                priority: (dictionary["priority"] as? NSNumber)?.intValue ?? 0
            )
        }
        return WebImageCandidateProcessor.filtered(candidates)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        update(from: webView, loading: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        update(from: webView, loading: false)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation?,
        withError error: Error
    ) {
        update(from: webView, loading: false)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: Error
    ) {
        update(from: webView, loading: false)
    }

    private func update(from webView: WKWebView, loading: Bool) {
        isLoading = loading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if let url = webView.url {
            addressText = url.absoluteString
        }
        pageTitle = webView.title?.isEmpty == false ? webView.title! : "Find Online"
    }

    private static let discoveryScript = #"""
    (() => {
      const found = [];
      const add = (value, width = 0, height = 0, description = '', priority = 0) => {
        if (!value || typeof value !== 'string') return;
        try {
          const url = new URL(value, document.baseURI).href;
          if (!/^https?:/i.test(url) || /\.svg(?:\?|$)/i.test(url)) return;
          found.push({ url, width: Number(width) || 0, height: Number(height) || 0,
                       description: String(description || ''), priority: Number(priority) || 0 });
        } catch (_) {}
      };

      document.querySelectorAll('meta[property="og:image"], meta[name="twitter:image"], meta[property="og:image:secure_url"]')
        .forEach(meta => add(meta.content, 0, 0, 'Page preview', 10000));

      document.querySelectorAll('img').forEach(img => {
        const width = img.naturalWidth || img.width || 0;
        const height = img.naturalHeight || img.height || 0;
        const description = img.alt || img.title || '';
        const priority = Math.min(9000, Math.round((width * height) / 1000));
        [img.currentSrc, img.src, img.getAttribute('data-src'), img.getAttribute('data-lazy-src'),
         img.getAttribute('data-original'), img.getAttribute('data-zoom-image')]
          .forEach(src => add(src, width, height, description, priority));
        const srcsets = [img.srcset, img.getAttribute('data-srcset')];
        srcsets.filter(Boolean).forEach(srcset => srcset.split(',').forEach(part => {
          const bits = part.trim().split(/\s+/);
          const hintedWidth = bits[1] && bits[1].endsWith('w') ? parseInt(bits[1]) : width;
          add(bits[0], hintedWidth, height, description, priority + 100);
        }));
      });

      document.querySelectorAll('picture source').forEach(source => {
        (source.srcset || '').split(',').forEach(part => {
          const bits = part.trim().split(/\s+/);
          add(bits[0], bits[1]?.endsWith('w') ? parseInt(bits[1]) : 0, 0, '', 200);
        });
      });

      document.querySelectorAll('[style*="background"], [class*="product"], [class*="hero"]').forEach((element, index) => {
        if (index > 600) return;
        const background = getComputedStyle(element).backgroundImage || '';
        const matches = [...background.matchAll(/url\(["']?([^"')]+)["']?\)/g)];
        matches.forEach(match => add(match[1], element.clientWidth, element.clientHeight, '', 100));
      });

      return found;
    })();
    """#
}

struct WebBrowserView: UIViewRepresentable {
    let model: WebBrowserModel

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = model
        webView.allowsBackForwardNavigationGestures = true
        model.attach(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
