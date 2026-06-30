// SPDX-License-Identifier: GPL-3.0-only
//  StatsBar.swift
//  Pilcrow for macOS
//
//  Bottom bar showing the selected primary statistic; clicking opens a popover
//  with every metric and a picker to choose which one the bar displays.

import SwiftUI

struct StatsBar: View {
    let stats: DocumentStats
    @AppStorage(SettingsKey.statDefault) private var statRaw = PrimaryStat.words.rawValue
    @State private var showingDetails = false

    private var primary: PrimaryStat { PrimaryStat(rawValue: statRaw) ?? .words }

    var body: some View {
        Button {
            showingDetails.toggle()
        } label: {
            Text(value(for: primary) + "  " + primary.label.lowercased())
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingDetails, arrowEdge: .bottom) {
            detailPopover
        }
    }

    private var detailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PrimaryStat.allCases) { stat in
                HStack {
                    Text(stat.label)
                    Spacer(minLength: 24)
                    Text(value(for: stat)).foregroundStyle(.secondary).monospacedDigit()
                }
                .font(.callout)
            }
            Divider()
            Picker("Show in bar", selection: $statRaw) {
                ForEach(PrimaryStat.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.menu)
            .font(.callout)
        }
        .padding(16)
        .frame(width: 240)
    }

    private func value(for stat: PrimaryStat) -> String {
        switch stat {
        case .characters: return "\(stats.characters)"
        case .words: return "\(stats.words)"
        case .sentences: return "\(stats.sentences)"
        case .paragraphs: return "\(stats.paragraphs)"
        case .readTime: return readingTime
        }
    }

    private var readingTime: String {
        let t = stats.readingTime
        if t.hours > 0 {
            return String(format: "%d:%02d:%02d", t.hours, t.minutes, t.seconds)
        }
        return String(format: "%d:%02d", t.minutes, t.seconds)
    }
}
