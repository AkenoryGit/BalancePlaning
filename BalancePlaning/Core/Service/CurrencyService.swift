//
//  CurrencyService.swift
//  BalancePlaning
//

import Foundation
import SwiftData

struct CurrencyService {
    let context: ModelContext

    func addCurrency(code: String, symbol: String, name: String) {
        guard let userId = currentUserId() else { return }
        let c = Currency(userId: userId, code: code.uppercased().trimmingCharacters(in: .whitespaces),
                         symbol: symbol.trimmingCharacters(in: .whitespaces),
                         name: name.trimmingCharacters(in: .whitespaces))
        context.insert(c)
        try? context.save()
    }

    func deleteCurrency(_ currency: Currency) {
        context.delete(currency)
        try? context.save()
    }
}
