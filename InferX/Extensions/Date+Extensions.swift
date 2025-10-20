
import Foundation

extension Date {
    func toFormatted(
        style: DateFormatter.Style = .medium,
        locale: Locale = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = style
        formatter.locale = locale
        return formatter.string(from: self)
    }

    func toTimeFormatted(
        style: DateFormatter.Style = .medium,
        locale: Locale = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = style
        formatter.locale = locale
        return formatter.string(from: self)
    }
    
    func toFullFormattedWithMilliseconds(locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = locale
        return formatter.string(from: self)
    }
}
