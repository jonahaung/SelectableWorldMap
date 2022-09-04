import Foundation
import UIKit

typealias JsonDictionary = [String: Any]

internal class WorldModelParser {
    func parse(json: JsonDictionary) -> [Country] {
        guard let features = json["features"] as? [JsonDictionary] else {
            return []
        }
        return features.compactMap(self.parseCountry)
    }

    private func parseCountry(country: JsonDictionary) -> Country? {
        guard let countryId = country["id"] as? String,
            let properties = country["properties"] as? JsonDictionary,
            let countryName = properties["name"] as? String,
            let geometryDict = country["geometry"] as? JsonDictionary,
            let geoType = geometryDict["type"] as? String else {
                return nil
        }

        if (geoType == "Polygon") {
            return Country(id: countryId, name: countryName, geometry: .polygon(self.parsePolygon(json: geometryDict)))
        } else if (geoType == "MultiPolygon") {
            return Country(id: countryId, name: countryName, geometry: .multiPolygon(self.parseMultiPolygon(json: geometryDict)))
        } else {
            print("Unrecognized type \(geoType)")
            return nil
        }
    }

    private func parsePolygon(json: JsonDictionary) -> [CGPoint] {
        guard let coordinates = json["coordinates"] as? [[[Double]]] else {
            return []
        }
        return self.parsePoints(points: coordinates)
    }

    private func parseMultiPolygon(json: JsonDictionary) -> [[CGPoint]] {
        guard let coordinates = json["coordinates"] as? [[[[Double]]]] else {
            return []
        }

        return coordinates.map(self.parsePoints)
    }

    private func parsePoints(points: [[[Double]]]) -> [CGPoint] {
        return points.flatMap{ $0 }.compactMap({ point in
            guard let x = point.first, let y = point.last else {
                return nil
            }
            return CGPoint(x: x, y: y)
        })
    }
}

internal struct Country {
    let id: String
    let name: String
    let geometry: Geometry
}

internal enum Geometry {
    case polygon([CGPoint])
    case multiPolygon([[CGPoint]])
}
