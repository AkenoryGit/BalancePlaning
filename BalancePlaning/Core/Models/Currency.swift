//
//  Currency.swift
//  BalancePlaning
//

import Foundation
import SwiftData

// MARK: - Предустановленные валюты (статика)

struct CurrencyInfo: Identifiable {
    let code: String
    let symbol: String
    let name: String
    var id: String { code }

    static var predefined: [CurrencyInfo] {
        let b = AppSettings.shared.bundle
        return [
            .init(code: "RUB",  symbol: "₽", name: b.localizedString(forKey: "Российский рубль",  value: "Российский рубль",  table: nil)),
            .init(code: "USD",  symbol: "$", name: b.localizedString(forKey: "Доллар США",          value: "Доллар США",          table: nil)),
            .init(code: "EUR",  symbol: "€", name: b.localizedString(forKey: "Евро",                value: "Евро",                table: nil)),
            .init(code: "GBP",  symbol: "£", name: b.localizedString(forKey: "Фунт стерлингов",    value: "Фунт стерлингов",    table: nil)),
            .init(code: "CNY",  symbol: "¥", name: b.localizedString(forKey: "Китайский юань",      value: "Китайский юань",      table: nil)),
            .init(code: "USDT", symbol: "₮", name: "Tether"),
            .init(code: "BTC",  symbol: "₿", name: "Bitcoin"),
            .init(code: "ETH",  symbol: "Ξ", name: "Ethereum"),
        ]
    }

    /// Символ по коду: сначала в предустановленных, затем в пользовательских, иначе сам код
    static func symbol(for code: String, custom: [Currency] = []) -> String {
        if let info = predefined.first(where: { $0.code == code }) { return info.symbol }
        if let c = custom.first(where: { $0.code == code }) { return c.symbol }
        return code
    }

    /// Полная информация по коду
    static func info(for code: String, custom: [Currency] = []) -> CurrencyInfo {
        if let info = predefined.first(where: { $0.code == code }) { return info }
        if let c = custom.first(where: { $0.code == code }) {
            return CurrencyInfo(code: c.code, symbol: c.symbol, name: c.name)
        }
        return CurrencyInfo(code: code, symbol: code, name: code)
    }

    /// Все доступные для пользователя валюты
    static func all(custom: [Currency]) -> [CurrencyInfo] {
        predefined + custom.map { CurrencyInfo(code: $0.code, symbol: $0.symbol, name: $0.name) }
    }
}

// MARK: - Пользовательская валюта (SwiftData)

@Model
class Currency {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var code: String    // например "MEME"
    var symbol: String  // например "M"
    var name: String    // например "Memecoin"

    init(id: UUID = UUID(), userId: UUID, code: String, symbol: String, name: String) {
        self.id = id
        self.userId = userId
        self.code = code
        self.symbol = symbol
        self.name = name
    }
}
