import Foundation

import SwiftyJSON
import Commander

enum NBConstants {
    public static let metadata: JSONSubscriptType = "metadata"
    public static let cells: JSONSubscriptType = "cells"
}

func cleanMetadata(_ json: inout JSON) {
    // TODO: Support exclude list.
    json[NBConstants.metadata] = JSON([String: Any?]())
}

func cleanCells(_ json: inout JSON) {
    let cells = json[NBConstants.cells]
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

    json[NBConstants.cells] = JSON(newCells)
}

func cleanNotebook(_ json: inout JSON) {
    cleanMetadata(&json)
    cleanCells(&json)
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

    cleanNotebook(&json)

    print(json)
}

main.run()
