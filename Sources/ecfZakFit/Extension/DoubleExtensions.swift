//
//  DoubleExtensions.swift
//  ecfZakFit
//
//  Created by cyrilH on 03/12/2025.
//

import Foundation

// MARK: - Double Extensions
/// Extensions utilitaires pour le type Double
extension Double {
    
    /// Arrondit un nombre décimal à un nombre spécifique de décimales
    /// - Parameter decimals: Le nombre de décimales souhaitées
    /// - Returns: Le nombre arrondi
    ///
    /// Exemple:
    /// ```swift
    /// let value = 123.456789
    /// value.roundedTo(2) // 123.46
    /// ```
    func roundedTo(_ decimals: Int) -> Double {
        let factor = Foundation.pow(10.0, Double(decimals))
        return (self * factor).rounded() / factor
    }
}
