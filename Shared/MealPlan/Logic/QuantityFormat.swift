import Foundation

enum QuantityFormat {
    /// "1.05 kg", "1.85 L", "200 g", "1.5 pcs". Large g/ml amounts switch to kg/L.
    static func string(_ quantity: Double, unit: String) -> String {
        if unit == "g", quantity >= 1000 {
            return "\(trimmed(quantity / 1000, maxDecimals: 2)) kg"
        }
        if unit == "ml", quantity >= 1000 {
            return "\(trimmed(quantity / 1000, maxDecimals: 2)) L"
        }
        let number = trimmed(quantity, maxDecimals: 1)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    /// Fixed-format number with trailing zeros removed (locale independent).
    private static func trimmed(_ value: Double, maxDecimals: Int) -> String {
        var text = String(format: "%.\(maxDecimals)f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }
}
