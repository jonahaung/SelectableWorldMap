import SwiftUI
import UIKit

open class WorldView: UIView {

    static var mapScale: CGFloat { 360.0 / 180.0 }
    public var countryColor: UIColor = .secondaryLabel.withAlphaComponent(0.7)
    public var selectedCountryColor: UIColor = .systemOrange.withAlphaComponent(0.5)
    private let borderWidth: CGFloat = 0.2
    private var intrinsicSize: CGSize {
        let screenSize = UIScreen.main.bounds.size
        let width = screenSize.height > screenSize.width ? screenSize.width : screenSize.height
        let height = width * 1/WorldView.mapScale
        return .init(width: width, height: height)
    }

    private let countries: [Country]

    override public init(frame: CGRect) {
        self.countries = WorldView.loadCountries()
        super.init(frame: frame)
        self.setupLayer()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.countries = WorldView.loadCountries()
        super.init(coder: aDecoder)
        self.setupLayer()
    }

    override open class var layerClass: AnyClass {
        return CATiledLayer.self
    }

    open var selectedCountries: [String] = [] {
        didSet {
            if oldValue != selectedCountries {
                self.setNeedsDisplay()
            }
        }
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if let first = touches.first {
            let location = first.location(in: self)
            let scale = self.bounds.width / self.intrinsicSize.width
            let scaleT = CGAffineTransform(scaleX: scale, y: -scale)
            let translateT = CGAffineTransform(translationX: self.intrinsicSize.width / 2, y: -self.intrinsicSize.height / 2)
            let selectedLocation = location.applying(scaleT.inverted()).applying(translateT.inverted())
            countries.forEach { country in
                switch (country.geometry) {
                case .polygon(let points):
                    select(points: points, country: country)
                case .multiPolygon(let polygons):
                    polygons.forEach { points in
                        select(points: points, country: country)
                    }
                }
            }

            func select(points: [CGPoint], country: Country)  {
                if selectedLocation.isInsidePolygon(polygon: points) {
                    selectedCountries = [country.name]
//                    if selectedCountries.contains(country.name) {
//                        if let index = selectedCountries.firstIndex(of: country.name) {
//                            self.selectedCountries.remove(at: index)
//                        }
//                    } else {
//                        selectedCountries.append(country.name)
//                    }
                }
            }
        }
    }

    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        let scale = self.bounds.width / self.intrinsicSize.width

        let context = UIGraphicsGetCurrentContext()!
        countries.forEach({ country in
            context.saveGState()
            context.setLineWidth(self.borderWidth * scale)
            context.setStrokeColor(UIColor.label.cgColor)

            let isSelected = selectedCountries.contains(country.name)
            let color = isSelected ? selectedCountryColor.cgColor : countryColor.cgColor
            context.setFillColor(color)

            context.scaleBy(x: scale, y: -scale)
            context.translateBy(x: self.intrinsicSize.width / 2, y: -self.intrinsicSize.height / 2)

            switch (country.geometry) {
            case .polygon(let points):

                self.drawPolygon(context: context, points: points, rect: rect)
            case .multiPolygon(let polygons):
                polygons.forEach {
                    self.drawPolygon(context: context, points: $0, rect: rect)
                }
            }
            
            context.drawPath(using: .fillStroke)
            context.restoreGState()
        })
    }

    private func setupLayer() {
        backgroundColor = UIColor.clear
        if let layer: CATiledLayer = self.layer as? CATiledLayer {
            layer.tileSize = CGSize(width: 1024, height: 1024)
            layer.levelsOfDetail = 5
            layer.levelsOfDetailBias = 2
        }
    }

    private static func loadCountries() -> [Country] {
        guard let asset = NSDataAsset(name: "world", bundle: Bundle(for: WorldView.self)),
              let json = try? JSONSerialization.jsonObject(with: asset.data, options: JSONSerialization.ReadingOptions.allowFragments),
              let jsonDict = json as? JsonDictionary else {
            return []
        }
        return WorldModelParser().parse(json: jsonDict)
    }

    private func drawPolygon(context: CGContext, points: [CGPoint], rect: CGRect) {

        for (index, point) in points.enumerated() {
            if (index == 0) {
                context.move(to: point)
            } else {
                context.addLine(to: point)
            }
        }
    }
}

extension WorldView {

    struct SwiftUIView: UIViewRepresentable {
        var selected: [String]
        func makeUIView(context: Context) -> WorldView {
            WorldView()
        }
        func updateUIView(_ uiView: WorldView, context: Context) {
            uiView.selectedCountries = selected
        }
    }
}

extension CGPoint {
    func isInsidePolygon(polygon: [CGPoint]) -> Bool {
        var pJ = polygon.last!
        var contains = false
        for pI in polygon {
            if ( ((pI.y >= self.y) != (pJ.y >= self.y)) &&
                 (self.x <= (pJ.x - pI.x) * (self.y - pI.y) / (pJ.y - pI.y) + pI.x) ){
                contains = !contains
            }
            pJ=pI
        }
        return contains
    }
}
