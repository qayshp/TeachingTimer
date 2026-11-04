// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import CryptoKit

// Captured privately by the release client, never printed in workflow logs.
func base64url(_ bytes: Data) -> String {
    bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

do {
    guard CommandLine.arguments.count == 4 else {
        throw NSError(domain: "TokenArguments", code: 1)
    }
    let pem = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
    let issued = Int(Date().timeIntervalSince1970)
    let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": CommandLine.arguments[2], "typ": "JWT"])
    let claims = try JSONSerialization.data(withJSONObject: ["iss": CommandLine.arguments[3], "iat": issued,
        "exp": issued + 900, "aud": "appstoreconnect-v1"])
    let message = base64url(header) + "." + base64url(claims)
    let signature = try key.signature(for: Data(message.utf8))
    print(message + "." + base64url(signature.rawRepresentation))
} catch {
    // Key contents and signing errors must not escape to public CI output.
    FileHandle.standardError.write(Data("Unable to create App Store Connect token.\n".utf8))
    exit(1)
}
