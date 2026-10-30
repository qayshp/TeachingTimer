// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchKit

/// Secondary management UI owns its draft and dismissal; runtime state remains independent.
struct ClassControlsView: View {
    enum Mode: Hashable { case summary, create, adjustNew, edit, settings }
    @ObservedObject var session: ExtendedRuntimeController
    @ObservedObject var classStore: ClassStore
    @ObservedObject var landmarks: LandmarkController
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .summary
    @State private var start = Date()
    @State private var defaultStart = Date()
    @State private var duration = 60
    @State private var confirmReplacement = false
    @State private var confirmEnd = false
    @AppStorage("countVibrationsEnabled") private var countVibrationsEnabled = true
    @AppStorage("showRemainingMinutes") private var showRemainingMinutes = false

    var body: some View {
        NavigationStack {
            Form {
                if mode == .settings {
                    Section {
                        Toggle("Count vibrations", isOn: $countVibrationsEnabled)
                            .accessibilityIdentifier("settings-count-vibrations")
                    } footer: {
                        Text("Off: visual counts only. Applies to the next count.")
                    }
                    Section {
                        Toggle("Minutes left", isOn: $showRemainingMinutes)
                            .accessibilityIdentifier("settings-minutes-left")
                    } footer: {
                        Text("Show minutes remaining on the timer face.")
                    }
                    Section {
                        Text("Saved for future classes. Music and system alerts are unchanged.")
                            .font(.caption)
                    }
                } else if mode == .summary, let current = classStore.context {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.scheduledStart.formatted(date: .omitted, time: .shortened) + "–" +
                                 current.scheduledEnd.formatted(date: .omitted, time: .shortened))
                                .font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text("\(current.durationMinutes) minutes").font(.caption)
                            if !session.statusText.isEmpty { Text(session.statusText).font(.caption) }
                            if !landmarks.lastResult.isEmpty { Text(landmarks.lastResult).font(.caption) }
                        }
                    }
                    Section {
                        classAction(session.isActive ? "Stop session" : "Resume session",
                                    icon: session.isActive ? "pause.fill" : "play.fill",
                                    prominent: !session.isActive) {
                            if session.isActive { session.stop() } else { session.start() }
                            dismiss()
                        }
                        .disabled(session.phase == .starting)
                        .accessibilityIdentifier("class-session-toggle")
                    } footer: {
                        Text("Stopping keeps class timing. Wrist-down updates may slow.")
                    }
                    Section("Schedule") {
                        classAction("Edit schedule", icon: "calendar") {
                            start = current.scheduledStart; duration = current.durationMinutes; mode = .edit
                        }.accessibilityIdentifier("edit-class-schedule")
                        classAction("New class", icon: "plus") { prepareNew() }
                            .accessibilityIdentifier("new-class")
                    }
                    settingsAction
                    Section {
                        classAction("End class", icon: "xmark.circle", role: .destructive) { confirmEnd = true }
                            .accessibilityIdentifier("end-class")
                    }
                } else if mode == .create {
                    Button(action: confirmStart) {
                        VStack(spacing: 6) {
                            ViewThatFits(in: .horizontal) {
                                Label("Start class", systemImage: "play.fill").fixedSize()
                                Label("Start", systemImage: "play.fill").fixedSize()
                            }
                            .font(.headline)
                            Text("60 minutes").font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                            VStack(spacing: 2) {
                                Text("Suggested time").font(.caption2)
                                    .lineLimit(1).minimumScaleFactor(0.65)
                                Text(defaultStart.formatted(date: .omitted, time: .shortened) + "–" +
                                     defaultStart.addingTimeInterval(3600).formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ClassActionStyle(prominent: true))
                    .listRowBackground(Color.clear)
                    .accessibilityLabel("Start 60-minute class")
                    .accessibilityValue("Suggested time: " + defaultStart.formatted(date: .omitted, time: .shortened) + " to " +
                        defaultStart.addingTimeInterval(3600).formatted(date: .omitted, time: .shortened))
                    .accessibilityIdentifier("confirm-class")
                    classAction("Custom schedule", icon: "slider.horizontal.3") { mode = .adjustNew }
                        .accessibilityIdentifier("adjust-class-schedule")
                    settingsAction
                } else {
                    Section("Scheduled start") {
                        if !Calendar.current.isDateInToday(start) {
                            Text(start.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                        }
                        VStack(spacing: 8) {
                            Text(start.formatted(date: .omitted, time: .shortened))
                                .font(.headline).frame(maxWidth: .infinity)
                            HStack(spacing: 8) {
                                Button("−15 min") { start = start.addingTimeInterval(-900) }
                                    .accessibilityLabel("Start fifteen minutes earlier")
                                    .accessibilityIdentifier("start-earlier")
                                Button("+15 min") { start = start.addingTimeInterval(900) }
                                    .accessibilityLabel("Start fifteen minutes later")
                                    .accessibilityIdentifier("start-later")
                            }
                            .buttonStyle(ClassActionStyle(compact: true))
                        }
                    }
                    Picker("Duration", selection: $duration) {
                        Text("60 min").tag(60)
                        Text("75 min").tag(75)
                    }
                    Text("Ends " + start.addingTimeInterval(Double(duration) * 60).formatted(date: .omitted, time: .shortened))
                    classAction(mode == .edit ? "Save schedule" : "Start class",
                                icon: mode == .edit ? "checkmark" : "play.fill", prominent: true,
                                action: confirmStart)
                        .accessibilityIdentifier("confirm-class")
                    if mode == .adjustNew {
                        Text("Only this class. The default stays 60 minutes at the suggested start.").font(.caption)
                        classAction("Default schedule", icon: "arrow.uturn.backward") { mode = .create }
                    }
                }
            }
            // A different task starts at its first row, not the summary's old
            // scroll offset. Only this Form is recreated; shared app state stays.
            .id(mode)
            .navigationTitle(mode == .settings ? "Settings" : (mode == .summary ? "Class" : (mode == .create ? "Start" : "Time")))
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(mode == .settings ? "Back" : (mode == .summary ? "Done" : "Cancel")) {
                    if mode == .settings { mode = classStore.context == nil ? .create : .summary }
                    else { dismiss() }
                }
            } }
        }
#if DEBUG
        // Sheet presentation can reset the environment inherited from TabView.
        // Apply the visual-test size explicitly to this presentation as well.
        .transformEnvironment(\.dynamicTypeSize) { size in
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--maximum-text") { size = .accessibility5 }
            else if arguments.contains("--accessibility-text") { size = .accessibility3 }
            else if arguments.contains("--large-text") { size = .xxxLarge }
        }
#endif
        .onAppear {
            if classStore.context == nil { prepareNew() }
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--show-settings") { mode = .settings }
            if ProcessInfo.processInfo.arguments.contains("--show-class-setup") {
                prepareNew()
                if ProcessInfo.processInfo.arguments.contains("--show-class-adjustments") {
                    mode = .adjustNew
                }
            }
#endif
        }
        .onChange(of: classStore.context) { _, context in
            // Retirement can occur while this sheet is open. Don't expose an
            // uninitialized schedule draft when the old summary disappears.
            if context == nil && mode == .summary { prepareNew() }
        }
        .alert("Start new class?", isPresented: $confirmReplacement) {
            Button("Start new", role: .destructive) { save() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Replaces timing and stops the count.") }
        .alert("End class?", isPresented: $confirmEnd) {
            Button("End class", role: .destructive) {
                session.stop(source: "new_class_reset")
                landmarks.cancel(reason: "new_class_reset")
                classStore.reset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Clears timing and stops the session and count.") }
    }

    private var settingsAction: some View {
        Section {
            classAction("Settings", icon: "gearshape") { mode = .settings }
                .accessibilityIdentifier("open-settings")
        }
    }

    private func classAction(_ title: String, icon: String, prominent: Bool = false,
                             role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 18).accessibilityHidden(true)
                Text(title).lineLimit(2).minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(ClassActionStyle(prominent: prominent, destructive: role == .destructive))
        .listRowBackground(Color.clear)
    }

    private func prepareNew() {
        start = ClassContext.inferredStart(for: Date())
        defaultStart = start
        duration = 60
        mode = .create
    }

    private func confirmStart() {
        if mode != .edit && classStore.context != nil { confirmReplacement = true }
        else { save() }
    }

    private func save() {
        if mode == .edit {
            classStore.updateSchedule(start: start, durationMinutes: duration)
        } else {
            landmarks.cancel(reason: "new_class_reset")
            // The confirmation is the actual Start action; opening the draft
            // earlier must not claim that the class was already running.
            classStore.begin(at: Date(), scheduledStart: mode == .create ? defaultStart : start,
                             durationMinutes: mode == .create ? 60 : duration)
            session.synchronizeClass(classStore.context)
            session.start()
        }
        dismiss()
    }
}

