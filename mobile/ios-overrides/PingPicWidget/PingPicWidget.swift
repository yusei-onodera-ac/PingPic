// Drop this file into mobile/ios/PingPicWidget/ after creating the Widget
// Extension target in Xcode, replacing the auto-generated version.
// See docs/IOS_WIDGET_SETUP.md.
//
// Reads data written by the `home_widget` Flutter package (see
// mobile/lib/features/widget_bridge/home_widget_service.dart) into the
// shared App Group container. Keys below ("promptText", "hasPostedToday")
// must match whatever HomeWidgetServiceImpl actually writes once that
// TODO is implemented — currently just a placeholder contract.

import WidgetKit
import SwiftUI

private let appGroupId = "group.com.pingpic.app"

struct PromptEntry: TimelineEntry {
    let date: Date
    let promptText: String
    let hasPostedToday: Bool
}

struct PingPicTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptEntry {
        PromptEntry(date: Date(), promptText: "お題を読み込み中…", hasPostedToday: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (PromptEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptEntry>) -> Void) {
        // TODO: reload is triggered externally via WidgetCenter.reloadTimelines
        // (called from Flutter through home_widget) rather than a fixed
        // in-widget refresh interval, since prompts change at unpredictable
        // times (T1/T2/T3, admin-configured).
        let timeline = Timeline(entries: [loadEntry()], policy: .never)
        completion(timeline)
    }

    private func loadEntry() -> PromptEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let promptText = defaults?.string(forKey: "promptText") ?? "お題はまだありません"
        let hasPostedToday = defaults?.bool(forKey: "hasPostedToday") ?? false
        return PromptEntry(date: Date(), promptText: promptText, hasPostedToday: hasPostedToday)
    }
}

struct PingPicWidgetView: View {
    var entry: PromptEntry

    var body: some View {
        // TODO: real layout — blurred/unblurred group post thumbnails per
        // the design doc's retention mechanic, not just text.
        VStack(alignment: .leading, spacing: 4) {
            Text("今日のお題").font(.caption).foregroundColor(.secondary)
            Text(entry.promptText).font(.headline).lineLimit(2)
            Text(entry.hasPostedToday ? "投稿済み ✓" : "未投稿")
                .font(.caption2)
                .foregroundColor(entry.hasPostedToday ? .green : .orange)
        }
        .padding()
        // TODO: widgetURL(...) deep link back into the app's /camera route.
    }
}

struct PingPicWidget: Widget {
    let kind: String = "PingPicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PingPicTimelineProvider()) { entry in
            PingPicWidgetView(entry: entry)
        }
        .configurationDisplayName("PingPic")
        .description("今日のお題と投稿状況を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
