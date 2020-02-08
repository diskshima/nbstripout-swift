import Foundation
import SwiftyJSON

let filepath = CommandLine.arguments[1]

let content = try String(contentsOf: URL.init(fileURLWithPath: filepath), encoding: .utf8)

if let data = content.data(using: .utf8, allowLossyConversion: false) {
    var json = try JSON(data: data)

    let cellsST: JSONSubscriptType = "cells"

    let cells = json[cellsST]
    var newCells: [JSON] = []

    for cell in cells.arrayValue {
        var newDict = JSON([String: Any?]())
        for (key, subJson): (String, JSON) in cell {
            var newValue: JSON
            switch key {
            case "metadata":
                newValue = JSON([String: Any?]())
            case "outputs":
                newValue = JSON([])
            case "execution_count":
                newValue = JSON.null
            default:
                newValue = subJson
            }

            newDict[key] = newValue
        }

        newCells.append(newDict)
    }

    json[cellsST] = JSON(newCells)

    print(json)
}
