// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchKit

/// Explicit action surfaces stay distinct from read-only Form rows in monochrome.
struct ClassActionStyle: ButtonStyle {
    var prominent = false
    var destructive = false
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .caption.weight(.semibold) : .body.weight(.semibold))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, compact ? 3 : 8).padding(.vertical, compact ? 0 : 4)
            .foregroundStyle(prominent ? Color.black : (destructive ? .red : .white))
            .background(prominent ? Color.white : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(prominent ? .clear : .white, lineWidth: 1))
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.65 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

