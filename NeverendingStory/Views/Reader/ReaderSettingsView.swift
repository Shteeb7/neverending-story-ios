//
//  ReaderSettingsView.swift
//  NeverendingStory
//
//  Reading preferences and settings
//

import SwiftUI

struct ReaderSettingsView: View {
    @StateObject private var settings = ReaderSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Font Size
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Font Size")
                                .font(.headline)

                            Spacer()

                            Text("\(Int(settings.fontSize))pt")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $settings.fontSize,
                            in: AppConfig.minFontSize...AppConfig.maxFontSize,
                            step: 1
                        )
                        .onChange(of: settings.fontSize) { _, _ in
                            settings.save()
                        }

                        // Preview text
                        Text("The quick brown fox jumps over the lazy dog")
                            .font(.system(size: settings.fontSize))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Typography")
                }

                // Line Spacing
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Line Spacing")
                                .font(.headline)

                            Spacer()

                            Text(lineSpacingLabel)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Picker("Line Spacing", selection: $settings.lineSpacing) {
                            Text("Compact").tag(CGFloat(1.2))
                            Text("Normal").tag(CGFloat(1.5))
                            Text("Relaxed").tag(CGFloat(2.0))
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: settings.lineSpacing) { _, _ in
                            settings.save()
                        }
                    }
                }

                // Font Family
                Section {
                    Picker("Font Family", selection: $settings.fontDesign) {
                        Text("System").tag(Font.Design.default)
                        Text("Serif").tag(Font.Design.serif)
                        Text("Rounded").tag(Font.Design.rounded)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.fontDesign) { _, _ in
                        settings.save()
                    }
                }

                // Color Scheme
                Section {
                    Picker("Theme", selection: $settings.colorScheme) {
                        Text("Light").tag(ReaderColorScheme.light)
                        Text("Dark").tag(ReaderColorScheme.dark)
                        Text("Auto").tag(ReaderColorScheme.auto)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.colorScheme) { _, _ in
                        settings.save()
                    }
                } header: {
                    Text("Appearance")
                }

                // Brightness (system control)
                Section {
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundColor(.secondary)

                        Slider(value: .constant(UIScreen.main.brightness), in: 0...1)
                            .disabled(true)

                        Image(systemName: "sun.max")
                            .foregroundColor(.secondary)
                    }

                    Text("Adjust brightness in Control Center")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Preview
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(.headline)

                        Text("In a world where memories can be stored and traded, you discover a hidden archive containing secrets that could unravel society. Every page turns with anticipation.")
                            .font(.system(
                                size: settings.fontSize,
                                design: settings.fontDesign
                            ))
                            .lineSpacing(settings.lineSpacing)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Reading Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var lineSpacingLabel: String {
        switch settings.lineSpacing {
        case 1.2:
            return "Compact"
        case 2.0:
            return "Relaxed"
        default:
            return "Normal"
        }
    }
}

#Preview {
    ReaderSettingsView()
}
