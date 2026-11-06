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

/// Read-only destinations share the existing Settings navigation stack.
/// They do not own or change class, runtime, count, or volume state.
struct AppInformationView: View {
    let page: AppInformationPage

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
            Section("Read the clock") {
                Text("The long hand shows seconds. The shorter, thicker hand shows minutes. Both show real time.")
                Text("The outer wedge marks the scheduled finish. For a 60-minute class, the stronger perimeter line shows time ahead. A 75-minute class shows the wedge only.")
            }
            Section("Start a class") {
                Text("Check the suggested start and end before starting. Custom schedule changes this class only; future classes still default to 60 minutes.")
                Text("The suggested start usually uses the previous quarter-hour. Use Custom schedule if you are starting early.")
            }
            Section("Session or class?") {
                Text("A session helps keep this app active for wrist-down teaching. Stop session keeps your class schedule; Resume session requests wrist-down support again. End class clears timing and stops the session and count.")
                Text("New class replaces the old class after confirmation. An old class also clears 30 minutes after its scheduled end.")
            }
            Section("One-minute count") {
                Text("Tap 1-min count to start the inner arc. Tap again to stop. The arc measures one minute from your tap.")
                Text("Groups of 1–6 vibrations begin every 10 seconds. The final group finishes after the minute. Vibrations may be late or skipped. Count vibrations in Settings applies to the next count.")
            }
            Section("Music and volume") {
                Text("Swipe left for media and right for the timer. Timer Crown volume targets the paired iPhone; Now Playing may show Watch playback instead.")
                Text("If media is blank or song progress is stuck, swipe away and back. If timer volume stops responding, tap its volume display to refresh, or visit media and return.")
                Text("If playback continues silently, try the iPhone’s volume controls. A refresh acknowledgement does not confirm that audio recovered.")
            }
            Section("Reopen the app") {
                Text("Saved class timing restores after reopening. A running session is recovered when possible; an intentional Stop stays stopped. Check Resume session if recovery fails. Force-closing the app ends an active count.")
            }
        }
    }

    private var privacy: some View {
        Group {
            Section("Your data") {
                Text("No account, ads, tracking, or analytics. Teaching Timer does not automatically send its diagnostic journals to the developer.")
            }
            Section("Stored on your Watch") {
                Text("Class times, session recovery intent, settings, and the latest count result are saved locally.")
                Text("Diagnostic journals record timestamps, app and system versions, session and interface events, count timing, and errors. They can reveal when you taught or used the app. They do not record song titles, audio, actual volume, health data, or poses.")
            }
            Section("Retention and removal") {
                Text("Journals retain up to seven days as events are written, capped at 10,000 session, 10,000 interface, and 20,000 count events. Heavy use can shorten that history.")
                Text("Unreadable journals may be saved as separate recovery files. Those copies are not cleared by the journal limits and can accumulate until separately removed or the app is deleted.")
                Text("End class clears current timing, not diagnostics or settings. Unreadable saved values may have a separate local recovery copy. Removing the app removes its local container; exported or backup copies are separate.")
            }
            Section("Sharing is your choice") {
                Text("Journal copying was verified with the maintainer’s TestFlight build and trusted Mac. Access for other testers is not established. This app has no journal export or upload.")
                Text("Share only what is needed. Do not post raw journals or system logs in public GitHub issues.")
                Text("Apple’s media services and system diagnostics follow your Apple settings. Data you choose to send to Apple or another recipient follows that recipient’s policies.")
            }
            Section {
                NavigationLink("Full privacy policy") {
                    LocalInformationDocument(title: "Policy", name: "PRIVACY", extension: "md")
                }
                InformationWebsiteLink(key: "privacy")
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
            Section {
                InformationWebsiteLink(key: "support")
            } header: {
                Text("Support")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email for private support:")
                    Text("teachingtimer@qays.net")
                        .font(.caption2).lineLimit(1).minimumScaleFactor(0.5)
                    Text("Include your app version and a short description. No logs are needed to start.")
                }
            }
            Section {
                InformationWebsiteLink(key: "source")
                NavigationLink("License: MPL 2.0") {
                    LocalInformationDocument(title: "License", name: "LICENSE", extension: nil)
                }
            } header: {
                Text("Open source")
            } footer: {
                Text("Read the license here. Website pages show an address and a QR code for your phone.")
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
            NavigationLink(site.title) {
                Form {
                    if let qrCode {
                        Section {
                            Image(qrCode, scale: 1, label: Text("QR code for " + site.title))
                                .interpolation(.none).resizable()
                                .frame(width: 120, height: 120)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }.listRowBackground(Color.white)
                    }
                    Section {
                        Text("Scan with your phone’s camera, or enter the address in a browser.")
                    }
                    Section("Address") {
                        Text(site.url.absoluteString).font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if key == "support" {
                        Section { Text("This page has the private support email. No GitHub account is needed to email support. Journals are not attached automatically.") }
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
