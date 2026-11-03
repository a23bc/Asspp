//
//  LogView.swift
//  Asspp
//
//  Created on 2026/2/20.
//

import SwiftUI

struct LogView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [String] = []
    @State private var unlocked = false

    private func fill() {
        messages = LogManager.shared.getMessages()
    }

    private func shareLog() {
        let text = LogManager.shared.exportText()
        guard !text.isEmpty else { return }
        let url = temporaryDirectory
            .appendingPathComponent("Asspp-\(Int(Date().timeIntervalSince1970)).log")
        guard (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil,
              AirDrop(items: [url])
        else {
            // Without a share surface, or if the write failed, fall back to the
            // pasteboard rather than dropping the log silently.
            copyToClipboard(text)
            return
        }
    }

    var body: some View {
        ZStack {
            if unlocked {
                VStack(spacing: 0) {
                    // Toolbar items placed inside a conditional branch can be
                    // dropped by the navigation bar on iOS 15, and a log page
                    // with no visible actions is useless, so keep them inline.
                    HStack(spacing: 20) {
                        Button(action: { fill() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        Button(action: { copyToClipboard(LogManager.shared.exportText()) }) {
                            Image(systemName: "doc.on.doc")
                        }
                        Button(action: shareLog) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Spacer()
                        Text("\(messages.count) lines")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    List {
                        ForEach(Array(messages.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.footnote, design: .monospaced))
                                .lineLimit(nil)
                                .textSelection(.enabled)
                        }
                    }
                    .transition(.opacity)
                    .groupedFormStyle()
                    .listStyle(.plain)
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                    Text("Sensitive Content")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                    Text("Logs may contain sensitive account information. Do not screenshot or share them to avoid leaking your credentials.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button(role: .destructive) {
                        unlocked = true
                        fill()
                    } label: {
                        Text("Show Logs")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.springDefault, value: unlocked)
        .navigationTitle("Logs")
    }
}
