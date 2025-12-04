//
//  array.swift
//  ecfZakFit
//
//  Created by cyrilH on 04/12/2025.
//

// MARK: - Array Extension for Async Map
/// Extension pour permettre le map asynchrone sur les tableaux
extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results = [T]()
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
}
