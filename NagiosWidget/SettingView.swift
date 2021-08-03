//
//  SettingView.swift
//  NagiosWidget
//
//  Created by m-hosoi on 2021/02/27.
//

import SwiftUI
import WidgetKit
import SwiftSoup

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

class SettingViewModel: ObservableObject {
    @Published var items:[SettingData] = [SettingData()]
}

struct SettingView: View {
    @ObservedObject var viewModel:SettingViewModel = SettingViewModel()
    init() {
        load()
    }
    var body: some View {
        Form{
            ForEach(viewModel.items.indices, id: \.self) { index in
                Section {
                    TextField("URL", text:self.$viewModel.items[index].URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    TextField("UserName", text:self.$viewModel.items[index].UserName)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.none)
                    SecureField("Password", text:self.$viewModel.items[index].Password)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.none)
                    if viewModel.items.count > 1 {
                        Button("Delete") {
                            viewModel.items.remove(at: index)
                        }
                    }
                }
            }
            Section {
                Button("Add") {
                    viewModel.items.append(SettingData())
                }
            }
            Section {
                Button("Save") {
                    save()
                }
            }
        }
    }
    
    private func save () {
        guard let jsonData = try? JSONEncoder().encode(viewModel.items) else {
            print("serialize error")
            return
        }
        let js = String(data: jsonData, encoding: .utf8)!
        let userDefaults = UserDefaults(suiteName: "group.NagiosWidget")
        if let userDefaults = userDefaults {
            userDefaults.synchronize()
            userDefaults.setValue(js, forKeyPath: "setting")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    private func load () {
        let settings = loadSetting()
        if settings.isEmpty {
            viewModel.items = [SettingData()]
        } else {
            viewModel.items = loadSetting()
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}

func loadSetting () -> [SettingData] {
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
//    fetchData(settings: items) { (res) in
//        print(res)
//    }
}

// https://engineer.dena.com/posts/2020.11/ios-widgetkit-tutorial/
func fetchData(settings:[SettingData], onSuccess: @escaping([[String]]) -> Void) {
    _fetchData(settings: settings, index: 0, dataRows: []) { result in
        onSuccess(result)
    }
}
func _fetchData(settings:[SettingData], index:Int, dataRows:[[String]], onSuccess: @escaping([[String]]) -> Void) {
    if index == settings.count {
        //        var ok = 0
        //        var total = 0
        //        var warning = 0
        //        var unknown = 0
        //        var critical = 0
        //        for row in dataRows {
        //            total += 1
        //            if row[2] == "OK" {
        //                ok += 1
        //            } else if row[2] == "WARNING" {
        //                warning += 1
        //            } else if row[2] == "CRITICAL" {
        //                critical += 1
        //            } else if row[2] == "UNKNOWN" {
        //                unknown += 1
        //            } else {
        //                print(row[2])
        //            }
        //        }
        //onSuccess("T: \(total)/ O:\(ok) / C:\(critical) / W: \(warning) / U:\(unknown)")
        onSuccess(dataRows)
        return
    }
    let setting = settings[index]
    guard let url = URL(string: setting.URL.hasSuffix("/")
                            ? "\(setting.URL)cgi-bin/status.cgi"
                            : "\(setting.URL)/cgi-bin/status.cgi") else { return }
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
