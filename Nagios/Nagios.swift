//
//  Nagios.swift
//  Nagios
//
//  Created by m-hosoi on 2021/02/27.
//

import WidgetKit
import SwiftUI
import Intents
import SwiftSoup

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        return SimpleEntry(
            date: Date(),
            configuration: ConfigurationIntent(),
            status: Status()
        )
    }
    
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        fetchData(settings: loadSetting()) { status in
            let entry = SimpleEntry(
                date: Date(),
                configuration: configuration,
                status: status
            )
            completion(entry)
        }
    }
    
    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        fetchData(settings: loadSetting()) { status in
            let entry = SimpleEntry(
                date: Date(),
                configuration: configuration,
                status: status
            )
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .after(refresh))
            completion(timeline)
        }
    }
    
    //    private func loadData () {
    //        let settings = loadSetting()
    //        print(settings)
    //    }
    
    private func loadSetting () -> [SettingData]{
        guard let userDefaults = UserDefaults(suiteName: "group.NagiosWidget") else {
            return []
        }
        guard let js = userDefaults.string(forKey: "setting") else {
            print("no data")
            return []
        }
        guard let items = try? JSONDecoder().decode([SettingData].self, from: js.data(using: .utf8)!) else {
            print("can't decode")
            return []
        }
        return items
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let status: Status
    func getStatusString() -> String {
        return "T: \(status.total)/ O:\(status.ok) / C:\(status.critical) / W: \(status.warning) / U:\(status.unknown)"
    }
}

struct NagiosEntryView : View {
    var entry: Provider.Entry
    let dateFormatter: DateFormatter
    
    init(entry: Provider.Entry) {
        self.entry = entry
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        ZStack {
            Color(entry.status.backgroundColor)
            VStack{
                Text("OK: \(entry.status.ok) / \(entry.status.total) ").font(.footnote).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
                Spacer()
                if entry.status.critical > 0 {
                    Text("Critical: \(entry.status.critical)").font(.callout).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
                    ForEach(entry.status.criticalAbout.indices, id: \.self) { i in
                        Text("\(entry.status.criticalAbout[i])").font(.footnote).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
                    }
                }
                if entry.status.warning > 0 {
                    Text("Warning: \(entry.status.warning)").font(.callout).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
                    if entry.status.critical == 0 {
                        ForEach(entry.status.warningAbout.indices, id: \.self) { i in
                            Text("\(entry.status.warningAbout[i])").font(.footnote).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
                        }
                    }
                }
                if entry.status.unknown > 0 {
                    Text("Unknown: \(entry.status.unknown)").font(.callout).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
                    if entry.status.critical == 0 && entry.status.warning == 0{
                        ForEach(entry.status.unknownAbout.indices, id: \.self) { i in
                            Text("\(entry.status.unknownAbout[i])").font(.footnote).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
                        }
                    }
                }
                if entry.status.isNoProblem {
                    Text("No problem").font(.title2).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
                }
                Spacer()
                Text(entry.date, formatter: dateFormatter).font(.footnote).foregroundColor(Color(entry.status.textColor)).multilineTextAlignment(.center)
            }.padding()
        }
    }
}

@main
struct Nagios: Widget {
    let kind: String = "Nagios"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            NagiosEntryView(entry: entry)
        }
        .configurationDisplayName("Nagios")
        .description("")
    }
}

struct Nagios_Previews: PreviewProvider {
    static var previews: some View {
        NagiosEntryView(entry: SimpleEntry(
                            date: Date(),
                            configuration: ConfigurationIntent(),
                            status: Status()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}


struct SettingData: Identifiable, Codable {
    var URL:String
    var UserName:String
    var Password:String
    init() {
        URL=""
        UserName=""
        Password=""
    }
    var id = UUID()
}

struct Status {
    var total:Int = 0
    var ok:Int = 0
    var warning:Int = 0
    var unknown:Int = 0
    var critical:Int = 0
    var warningAbout:[String] = []
    var criticalAbout:[String] = []
    var unknownAbout:[String] = []
    
    var isNoProblem: Bool {
        get {
            return warning == 0 && critical == 0 && unknown == 0
        }
    }
    var backgroundColor: UIColor {
        get {
            return critical > 0 ? .red
                : warning > 0 ? .yellow
                : unknown > 0 ? .gray
                : UIColor.systemBackground
        }
    }
    var textColor: UIColor {
        get {
            return critical > 0 ? .white
                : warning > 0 ? .black
                : unknown > 0 ? .white
                : UIColor.label
        }
    }
}

// https://engineer.dena.com/posts/2020.11/ios-widgetkit-tutorial/
func fetchData(settings:[SettingData], onSuccess: @escaping(Status) -> Void) {
    _fetchData(settings: settings, index: 0, dataRows: [], onSuccess: onSuccess)
}
func _fetchData(settings:[SettingData], index:Int, dataRows:[[String]], onSuccess: @escaping(Status) -> Void) {
    if index == settings.count {
        var status = Status()
        var host:String = ""
        for row in dataRows {
            if row[0] != "" {
                host = row[0]
            }
            status.total += 1
            if row[2] == "OK" {
                status.ok += 1
            } else if row[2] == "WARNING" {
                status.warning += 1
                status.warningAbout += ["\(host):\(row[1])"]
            } else if row[2] == "CRITICAL" {
                status.critical += 1
                status.criticalAbout += ["\(host):\(row[1])"]
            } else if row[2] == "UNKNOWN" {
                status.unknown += 1
                status.unknownAbout += ["\(host):\(row[1])"]
            } else {
                print(row[2])
            }
        }
        onSuccess(status)
        return
    }
    let setting = settings[index]
    guard let url = URL(string: setting.URL.hasSuffix("/")
                            ? "\(setting.URL)cgi-bin/status.cgi"
                            : "\(setting.URL)/cgi-bin/status.cgi") else { return }
    print(url)
    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    guard let credentialData = "\(setting.UserName):\(setting.Password)".data(using: String.Encoding.utf8) else { return }
    let credential = credentialData.base64EncodedString(options: [])
    let basicData = "Basic \(credential)"
    req.setValue(basicData, forHTTPHeaderField: "Authorization")
    
    URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if let resp = resp as? HTTPURLResponse {
            if resp.statusCode >= 400 {
                print("Error: \(resp.statusCode) \(url)")
                let res = { () ->[[String]] in
                    if resp.statusCode == 401 {
                        return [
                            [setting.URL, "", "", "", "", "", ""],
                            ["", "Connection", "WARNING", "", "", "", "Unauthorized"]
                        ]
                    }
                    if resp.statusCode >= 500 {
                        return [
                            [setting.URL, "", "", "", "", "", ""],
                            ["", "Connection", "WARNING", "", "", "", "Server Error"]
                        ]
                    }
                    return [
                        [setting.URL, "", "", "", "", "", ""],
                        ["", "Connection", "WARNING", "", "", "", "Error \(resp.statusCode)"]
                    ]
                }()
                _fetchData(settings: settings, index: index + 1, dataRows: dataRows + res, onSuccess: onSuccess)
                return
            }
        }
        guard let data = data else { return }
        guard let doc = try? SwiftSoup.parse(String(data: data, encoding: .utf8)!) else {
            print("parse error")
            return
        }
        guard let rows = try? doc.select("table.status > tbody > tr") else {
            print("rows not found")
            return
        }
        let res = rows.array().dropFirst().map {
            $0.children().array().map {
                try! $0.text()
            }
        }.filter{ $0.count == 7 }
        _fetchData(settings: settings, index: index + 1, dataRows: dataRows + res, onSuccess: onSuccess)
    }.resume()
}
