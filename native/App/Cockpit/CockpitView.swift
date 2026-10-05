//  The Cockpit screen: the page full screen, no header, a slim footer with Done (the native app's "just the footer is
//  fine"). The web view belongs to CockpitModel, so Done hides the page instead of throwing it away.

import SwiftUI
import UIKit
import WebKit

private let accent = Color(red: 0.298, green: 0.788, blue: 0.941)

/// Hands SwiftUI the model's one web view each time the screen appears, rather than making a new one.
private struct WebViewHost: UIViewRepresentable {
  let webView: WKWebView
  func makeUIView(context: Context) -> WKWebView { webView }
  func updateUIView(_ view: WKWebView, context: Context) {}
}

struct CockpitView: View {
  @ObservedObject var model: CockpitModel
  let onDone: () -> Void
  @State private var copied = false

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        WebViewHost(webView: model.webView)
          .opacity(model.error == nil ? 1 : 0)
        if let error = model.error {
          errorPanel(error)
        } else if model.loading {
          VStack(spacing: 10) {
            ProgressView().controlSize(.large).tint(accent)
            Text("Cockpit").font(.footnote).kerning(1).foregroundStyle(.gray)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(cockpitBackground)
          .accessibilityIdentifier("cockpit-loading")
        }
      }
      footer
    }
    .background(cockpitBackground.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .onAppear { model.appeared() }
  }

  private var footer: some View {
    HStack {
      Button(action: onDone) {
        Label("Done", systemImage: "chevron.left").font(.system(size: 15, weight: .semibold))
      }
      .foregroundStyle(accent)
      .accessibilityIdentifier("cockpit-done")
      Spacer()
      Text("Cockpit").font(.caption).foregroundStyle(.gray)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color.black.opacity(0.35))
  }

  private func errorPanel(_ error: CockpitModel.LoadError) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text("Can't reach the Cockpit").font(.title3.weight(.bold)).foregroundStyle(.white)
        Text("Check that Tailscale is connected and the machine serving the Cockpit is awake.")
          .font(.subheadline).foregroundStyle(Color(white: 0.67))
        Text(error.url).font(.system(.footnote, design: .monospaced)).foregroundStyle(accent).textSelection(.enabled)
        Button("Try again") { model.retry() }
          .font(.system(size: 15, weight: .semibold))
          .padding(.horizontal, 18).padding(.vertical, 10)
          .background(Color(red: 0.141, green: 0.204, blue: 0.278), in: RoundedRectangle(cornerRadius: 8))
          .foregroundStyle(accent)
          .accessibilityIdentifier("cockpit-retry")
        // The app's copyable error: the message, and a button that carries it with the address and the build.
        VStack(alignment: .leading, spacing: 8) {
          Text(error.message).font(.footnote).foregroundStyle(Color(red: 1, green: 0.55, blue: 0.55))
            .textSelection(.enabled)
          Button(copied ? "Copied" : "Copy error") {
            UIPasteboard.general.string = model.errorReport()
            copied = true
          }
          .font(.footnote.weight(.semibold)).foregroundStyle(accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      }
      .padding(24)
    }
    .accessibilityIdentifier("cockpit-error")
    .onChange(of: error) { copied = false }
  }
}
