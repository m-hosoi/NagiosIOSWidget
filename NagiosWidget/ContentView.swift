//
//  ContentView.swift
//  NagiosWidget
//
//  Created by m-hosoi on 2021/02/27.
//

import SwiftUI

@ViewBuilder
func getRow(row: [String]) -> some View {
    if row[0] != "" {
        HStack {
            Spacer()
            Text(row[0])
            Spacer()
        }
    } else {
        let color = row[2] == "WARNING" ? Color.black
            : row[2] == "CRITICAL" ? Color.white
            : row[2] == "UNKNOWN" ? Color.white
            : Color(UIColor.label)
        HStack {
            Text(row[1]).font(.caption).foregroundColor(color)
            //Text(rows[i][2]).font(.caption)
            Spacer()
            Text(row[6]).font(.caption).foregroundColor(color)
        }.listRowBackground(row[2] == "WARNING" ? Color.yellow
                                : row[2] == "CRITICAL" ? Color.red
                                : row[2] == "UNKNOWN" ? Color.gray
                                : Color(UIColor.systemBackground))
    }
}

struct ContentView: View {
    @State private var rows:[[String]] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(rows.indices, id: \.self) { i in
                    getRow(row: rows[i])
                }
            }
            .onAppear(perform: {
                //                self.rows = [
                //                    ["TEST", "", "", "", "", "", ""],
                //                    ["", "TEST", "WARNING", "", "", "", "ABOUT"],
                //                    ["", "TEST", "ERROR", "", "", "", "ABOUT"],
                //                ]
                fetchData(settings: loadSetting())  { [_self = self]  in
                    _self.rows = $0
                }
            })
            .navigationBarTitle("nagios", displayMode: .inline)
            .navigationBarItems(trailing: NavigationLink(destination: SettingView()) {
                Image(systemName: "gearshape")
            })
        }
        .navigationViewStyle(StackNavigationViewStyle()) // for iPad
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
