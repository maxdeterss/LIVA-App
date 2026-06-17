import Foundation

/// Google encoded-polyline codec (precision 5). Compact route storage for the
/// `workouts.polyline` column and quick map rendering.
enum Polyline {
    static func encode(_ coords: [(lat: Double, lng: Double)]) -> String {
        var result = ""
        var prevLat = 0, prevLng = 0
        for c in coords {
            let lat = Int((c.lat * 1e5).rounded())
            let lng = Int((c.lng * 1e5).rounded())
            result += encodeValue(lat - prevLat)
            result += encodeValue(lng - prevLng)
            prevLat = lat; prevLng = lng
        }
        return result
    }

    static func decode(_ string: String) -> [(lat: Double, lng: Double)] {
        var coords: [(Double, Double)] = []
        var index = string.startIndex
        var lat = 0, lng = 0
        let chars = Array(string.unicodeScalars)
        var i = 0
        func nextValue() -> Int? {
            var shift = 0, result = 0
            while i < chars.count {
                let b = Int(chars[i].value) - 63
                i += 1
                result |= (b & 0x1F) << shift
                shift += 5
                if b < 0x20 { break }
            }
            let delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            return delta
        }
        _ = index
        while i < chars.count {
            guard let dLat = nextValue(), let dLng = nextValue() else { break }
            lat += dLat; lng += dLng
            coords.append((Double(lat) / 1e5, Double(lng) / 1e5))
        }
        return coords
    }

    private static func encodeValue(_ value: Int) -> String {
        var v = value < 0 ? ~(value << 1) : (value << 1)
        var output = ""
        while v >= 0x20 {
            output.unicodeScalars.append(UnicodeScalar((0x20 | (v & 0x1F)) + 63)!)
            v >>= 5
        }
        output.unicodeScalars.append(UnicodeScalar(v + 63)!)
        return output
    }
}
