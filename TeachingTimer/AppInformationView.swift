// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import ImageIO

enum AppInformationPage: String, CaseIterable, Identifiable {
    case help, privacy, about

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .help: "questionmark.circle"
        case .privacy: "hand.raised"
        case .about: "info.circle"
        }
    }
}

/// Information and optional diagnostic sharing use the existing Settings stack.
/// They do not own or change class, runtime, count, or volume state.
struct AppInformationView: View {
    let page: AppInformationPage
    let prepareDiagnostics: @MainActor (DiagnosticReport.Window, Set<URL>) async throws -> DiagnosticSharingView.Prepared

    var body: some View {
        Form {
            switch page {
            case .help: help
            case .privacy: privacy
            case .about: about
            }
        }
        .navigationTitle(page.title)
    }

    private var help: some View {
        Group {
            Section("Using Teaching Timer") {
                ForEach(HelpTopic.allCases) { topic in
                    NavigationLink {
                        HelpTopicView(topic: topic)
                    } label: {
                        Label(topic.title, systemImage: topic.symbol)
                    }
                    .accessibilityIdentifier("help-" + topic.rawValue)
                }
            }
            Section {
                InformationWebsiteLink(key: "support")
                NavigationLink {
                    DiagnosticSharingView(prepare: prepareDiagnostics)
                } label: {
                    Label("Send diagnostics to iPhone", systemImage: "iphone.and.arrow.forward")
                }
                .accessibilityIdentifier("help-send-diagnostics")
            } header: {
                Text("Support")
            } footer: {
                Text("A description is enough to ask for help. Share diagnostics after class.")
            }
        }
    }

    private var privacy: some View {
        Group {
            Section("Your privacy") {
                Text("No account, ads, tracking, or analytics. Nothing is automatically uploaded to the developer.")
            }
            Section("On your devices") {
                Text("Class timing, settings and diagnostic history stay on your Watch. Journals can reveal when you used the app; they exclude song titles, audio, actual volume, health data and poses.")
                Text("History is limited to seven days and event caps. Heavy use can shorten it. End class does not erase diagnostics or settings.")
            }
            Section("Optional sharing") {
                Text("Help → Send diagnostics to iPhone, or a request from the phone app, prepares a filtered report. Review it on your phone before emailing. Nothing is emailed automatically.")
                Text("The phone keeps the latest report until replaced or deleted. Recipient copies are separate. Do not post raw reports publicly.")
            }
            Section {
                NavigationLink("Full policy on Watch") {
                    LocalInformationDocument(title: "Policy", name: "PRIVACY", extension: "md")
                }
                InformationWebsiteLink(key: "privacy", label: "Read policy on iPhone")
            } footer: {
                Text("The full policy includes storage limits, recovery copies and removal details. It is available here offline.")
            }
        }
    }

    private var about: some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName).font(.headline)
                    Text(versionText)
                    Text("A teaching clock for Apple Watch.")
                }
            }
            Section("Open source") {
                InformationWebsiteLink(key: "source")
                NavigationLink("License: MPL 2.0") {
                    LocalInformationDocument(title: "License", name: "LICENSE", extension: nil)
                }
            }
        }
    }

    private var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Teaching Timer"
    }

    private var versionText: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return "Version unavailable"
        }
        return "Version \(version) (\(build))"
    }
}

private enum HelpTopic: String, CaseIterable, Identifiable {
    case music, clock, count, session
    var id: Self { self }
    var title: String {
        switch self {
        case .music: "Music & volume"
        case .clock: "Class timing"
        case .count: "One-minute count"
        case .session: "Sessions & recovery"
        }
    }
    var navigationTitle: String {
        switch self {
        case .count: "Count"
        case .session: "Sessions"
        default: title
        }
    }
    var symbol: String {
        switch self {
        case .music: "speaker.wave.2"
        case .clock: "clock"
        case .count: "timer"
        case .session: "arrow.clockwise"
        }
    }
}

private struct HelpTopicView: View {
    let topic: HelpTopic
    var body: some View {
        Form {
            switch topic {
            case .music:
                Section("Media stuck?") {
                    Text("If media is blank or song progress is stuck, swipe to the timer and back.")
                }
                Section("Volume not responding?") {
                    Text("Tap the timer’s volume display to refresh, or visit media and return. If playback continues silently, try the iPhone’s volume controls.")
                }
                Section("Playback source") {
                    Text("Timer Crown volume targets the paired iPhone. Now Playing may show Watch playback instead. A refresh acknowledgement does not confirm audio recovery.")
                }
            case .clock:
                Section("Read the clock") {
                    Text("The long hand shows seconds; the shorter, thicker hand shows minutes. Both show real time.")
                    Text("The outer wedge marks the scheduled finish. For a 60-minute class, the stronger perimeter line shows time ahead. A 75-minute class shows the wedge only.")
                }
                Section("Start a class") {
                    Text("Check the suggested start and finish. The start usually uses the previous quarter-hour. Custom schedule changes this class only; future classes still default to 60 minutes.")
                }
                Section("Between classes") {
                    Text("New class replaces the old class after confirmation. An old class clears 30 minutes after its scheduled finish.")
                }
            case .count:
                Section("Visual count") {
                    Text("Tap 1-min count to start the inner arc. Tap again to stop. The arc measures one minute from your tap.")
                }
                Section("Optional vibrations") {
                    Text("Groups of 1–6 vibrations begin every 10 seconds. The final group finishes after the minute. Vibrations may be late or skipped.")
                    Text("Count vibrations in Settings applies to the next count. Turn it off for visual counts only.")
                }
            case .session:
                Section("Wrist-down updates") {
                    Text("A session helps keep the app active for wrist-down teaching. Stop session keeps your class schedule. Start session or Resume session requests wrist-down support.")
                }
                Section("Reopen the app") {
                    Text("Saved class timing restores. A running session recovers when possible; an intentional Stop stays stopped. Use Start session or Resume session if needed.")
                    Text("Force-closing ends an active count. End class clears timing and stops the session and count.")
                }
            }
        }
        .navigationTitle(topic.navigationTitle)
    }
}

private struct InformationWebsite: Decodable {
    let title: String
    let url: URL
    static let all: [String: Self] = {
        guard let file = Bundle.main.url(forResource: "WebLinks", withExtension: "json", subdirectory: "Information"),
              let data = try? Data(contentsOf: file),
              let sites = try? JSONDecoder().decode([String: Self].self, from: data) else { return [:] }
        return sites
    }()
}

private struct InformationWebsiteLink: View {
    let key: String
    var label: String? = nil

    private var navigationTitle: String {
        switch key {
        case "support": "Support"
        case "privacy": "Privacy"
        default: "Source"
        }
    }

    private var qrCode: CGImage? {
        guard let file = Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "Information"),
              let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    var body: some View {
        if let site = InformationWebsite.all[key] {
            NavigationLink(label ?? site.title) {
                Form {
                    if let qrCode {
                        Section {
                            Image(qrCode, scale: 1, label: Text("QR code for " + site.title))
                                .interpolation(.none).resizable()
                                .scaledToFit()
                                .frame(maxWidth: 120, maxHeight: 120)
                                .frame(maxWidth: .infinity)
                                .padding(6)
                        } footer: {
                            Text("Scan with your iPhone camera to open this page.")
                        }
                        .listRowBackground(Color.white)
                    }
                    if key == "support" {
                        Section("Email support") {
                            Text("teachingtimer@qays.net").font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Include the app version and a short description. No logs or GitHub account are needed.")
                        }
                    }
                    Section {
                        NavigationLink("Website address") {
                            Form {
                                Text(site.url.absoluteString).font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.navigationTitle("Address")
                        }
                    }
                }.navigationTitle(navigationTitle)
            }
        } else {
            Text("Website address unavailable in this copy.")
        }
    }
}

/// The policy and license are copied from the repository originals at build time.
/// Show complete local documents without any web view or network dependency.
private struct LocalInformationDocument: View {
    let title: String
    private let paragraphs: [String]

    init(title: String, name: String, extension suffix: String?) {
        self.title = title
        if let file = Bundle.main.url(forResource: name, withExtension: suffix),
           let text = try? String(contentsOf: file, encoding: .utf8) {
            paragraphs = text.replacingOccurrences(of: "\n- ", with: "\n\n• ")
                .components(separatedBy: "\n\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else {
            paragraphs = ["This document is missing from this copy of the app."]
        }
    }

    var body: some View {
        Form {
            ForEach(paragraphs.indices, id: \.self) { index in
                let paragraph = paragraphs[index]
                let heading = paragraph.hasPrefix("#") || paragraph.contains("\n===") || paragraph.contains("\n---")
                Text(displayText(paragraph))
                    .font(heading ? .headline : .body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.navigationTitle(title)
    }

    private func displayText(_ paragraph: String) -> String {
        paragraph.split(separator: "\n")
            .filter { !$0.allSatisfy { $0 == "=" || $0 == "-" } }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            .replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "$1 ($2)", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
    }
}
