//  Diagnostics uploads (stories 094, 095): the GitHub token, once; the automatic upload after a troubled call; the
//  last upload; and deleting everything this app uploaded. The token is never shown once saved.

import ContextCore
import SwiftUI
import UIKit

struct GistSettingsView: View {
  @ObservedObject var call: CallModel
  @State private var token = ""
  @State private var error: String?
  @State private var deleteResult = ""
  @State private var deleting = false

  var body: some View {
    Form {
      Section {
        SecureField(call.hasToken ? "token saved" : "GitHub token", text: $token)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .onSubmit(save)
        if call.hasToken {
          Button("Forget the token", role: .destructive) {
            token = ""
            save()
          }
        }
        if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
      } footer: {
        Text("A classic token with only the gist scope; fine-grained tokens cannot create gists. Kept in the Keychain.")
      }
      if call.hasToken {
        Section {
          Toggle("Upload after a troubled call", isOn: $call.autoUpload)
          if let url = call.lastUploadURL {
            HStack {
              Text(url).font(.footnote).textSelection(.enabled)
              Spacer()
              Button("Copy") { UIPasteboard.general.string = url }
            }
          }
          Button(deleting ? "Deleting…" : "Delete uploaded diagnostics (\(call.uploads.count))") {
            deleting = true
            Task {
              deleteResult = await call.deleteUploads()
              deleting = false
            }
          }
          .disabled(deleting || call.uploads.isEmpty)
          if !deleteResult.isEmpty { Text(deleteResult).foregroundStyle(.secondary) }
        } footer: {
          Text("Each upload is a secret gist that asks its reader to delete it. The app keeps its newest ten.")
        }
      }
    }
    .navigationTitle("Diagnostics uploads")
  }

  private func save() {
    do {
      try call.setToken(token)
      token = ""
      error = nil
    } catch {
      self.error = describe(error)
    }
  }
}
