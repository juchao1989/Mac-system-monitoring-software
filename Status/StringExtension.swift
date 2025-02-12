import Foundation

extension String {
    var nilIfEmpty: String? {
        return self.isEmpty ? nil : self
    }
}