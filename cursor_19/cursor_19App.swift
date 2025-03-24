//
//  cursor_19App.swift
//  cursor_19
//
//  Created by Jason Reid on 24/03/2025.
//

import SwiftUI

/**
 * Face Liveness Detection App
 *
 * This is the main application entry point for the Face Liveness Detection app.
 * The app demonstrates how to use TrueDepth camera capabilities to distinguish
 * between real human faces and spoof attempts (photos/videos).
 *
 * Key features:
 * - Real-time face detection
 * - Depth analysis for liveness verification
 * - Simple user interface with test cycle
 *
 * See README.md for more detailed information about the app architecture
 * and implementation details.
 */
@main
struct cursor_19App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
