//
//  advice_slip_widget.swift
//  advice_slip_widget
//
//  Created by Zsolt Kébel on 28/01/2024.
//

import WidgetKit
import SwiftUI

import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct RefreshAdviceSlip: AppIntent {
    static var title: LocalizedStringResource = "RefreshAdviceSlip"
    
    func perform() async throws -> some IntentResult {
        cachedAdvice = nil
        return .result()
    }
}

let refreshTime = 15 // in mins
var cachedAdvice: String?

struct AdviceSlipResponse: Codable {
    let slip: AdviceSlip
}

struct AdviceSlip: Codable, Hashable {
    let id: Int
    let advice: String
}

func getAdviceSlip() async throws -> AdviceSlip {
    guard let url = URL(string: "https://api.adviceslip.com/advice") else { fatalError("Missing URL") }
    print("fetching data")
    // Use the async variant of URLSession to fetch data
    // Code might suspend here
    let (data, _) = try await URLSession.shared.data(from: url)
    
    // Parse the JSON data
    let adviceSlipResult = try JSONDecoder().decode(AdviceSlipResponse.self, from: data)
    return adviceSlipResult.slip
}

struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), emoji: "😀", advice: "If you don't want something to be public, don't post it on the Internet.")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), emoji: "😀", advice: "If you don't want something to be public, don't post it on the Internet.")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            if cachedAdvice == nil {
                // Fetch a random doggy image from server
                guard let slip = try? await getAdviceSlip() else {
                    return
                }
                cachedAdvice = slip.advice
            }
            
            let entry = SimpleEntry(date: Date(), emoji: "😀", advice: cachedAdvice ?? "...")
            
            // Next fetch happens 15 minutes later
            let nextUpdate = Calendar.current.date(
                byAdding: DateComponents(minute: refreshTime),
                to: Date()
            )!
            
            let timeline = Timeline(
                entries: [entry],
                policy: .after(nextUpdate)
            )
            
            completion(timeline)
        }
        
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let emoji: String
    let advice: String
}

struct advice_slip_widgetEntryView : View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) var family
    
    var dateFormatter = DateFormatter()
        
    var body: some View {
        switch family {
        case .systemSmall:
            VStack {
                Spacer(minLength: 0)
                Text(entry.advice)
                    .minimumScaleFactor(0.1)
                Spacer(minLength: 5)
                HStack {
                    RefreshButton()
                    Spacer(minLength: 0)
                    VStack {
                        HStack {
                            Spacer(minLength: 0)
                            Text("Next \(DateFormatter.localizedString(from: Calendar.current.date(byAdding: DateComponents(minute: refreshTime), to: entry.date)!, dateStyle: .none, timeStyle: .short))")
                        }
                    }
                    .foregroundStyle(.secondary)
                }.font(.footnote)
            }
        default:
            VStack {
                Spacer(minLength: 0)
                Text(entry.advice)
                Spacer(minLength: 5)
                HStack {
                    RefreshButton()
                    //TODO: Implement save button
//                    if #available(iOS 17.0, *) {
//                        HStack(alignment: .top) {
//                            Button(intent: RefreshAdviceSlip()) {
//                                Image(systemName: "bookmark")
//                            }.buttonStyle(.bordered).tint(.gray)
//                        }
//                    }
                    Spacer(minLength: 0)
                    VStack {
                        HStack {
                            Spacer(minLength: 0)
                            Text("Recieved \(DateFormatter.localizedString(from: entry.date, dateStyle: .none, timeStyle: .short))")
                        }
                        HStack {
                            Spacer(minLength: 0)
                            Text("Next \(DateFormatter.localizedString(from: Calendar.current.date(byAdding: DateComponents(minute: refreshTime), to: entry.date)!, dateStyle: .none, timeStyle: .short))")
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        }
    }
}

struct advice_slip_widget: Widget {
    let kind: String = "advice_slip_widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                advice_slip_widgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                advice_slip_widgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

#Preview(as: .systemMedium) {
    advice_slip_widget()
} timeline: {
    SimpleEntry(date: .now, emoji: "😀", advice: "If you don't want something to be public, don't post it on the Internet.")
    SimpleEntry(date: .now, emoji: "🤩", advice: "If you don't want something to be public, don't post it on the Internet.")
}

struct RefreshButton: View {
    var body: some View {
        if #available(iOS 17.0, *) {
            HStack(alignment: .top) {
                Button(intent: RefreshAdviceSlip()) {
                    Image(systemName: "arrow.clockwise")
                }.buttonStyle(.bordered)
            }
        }
    }
}
