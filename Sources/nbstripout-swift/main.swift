import Foundation

import SwiftyJSON
import Commander

let metadataST: JSONSubscriptType = "metadata"
let cellsST: JSONSubscriptType = "cells"

func cleanMetadata(_ json: inout JSON) {
    // TODO: Support exclude list.
    json[metadataST] = JSON([String: Any?]())
}

func cleanCells(_ json: inout JSON) {
    let cells = json[cellsST]
    var newCells: [JSON] = []

    for cell in cells.arrayValue {
        var newDict = JSON([String: Any?]())
        for (key, subJson): (String, JSON) in cell {
            var newValue: JSON
            switch key {
            case "metadata":
                // TODO: Support exclude list.
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
}

let main = command { (filepath: String) in
    let data: Data
    do {
        let content = try String(contentsOfFile: filepath, encoding: .utf8)
        data = content.data(using: .utf8, allowLossyConversion: false)!
    } catch {
        print("Failed to read file.")
        return
    }

    var json: JSON
    do {
        json = try JSON(data: data)
    } catch {
        print("Failed to convert data to JSON.")
        return
    }

    cleanMetadata(&json)
    cleanCells(&json)

    print(json)
}

main.run()
