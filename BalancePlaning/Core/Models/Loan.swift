//
//  Loan.swift
//  BalancePlaning
//

import Foundation
import SwiftData

@Model
class Loan {
    @Attribute(.unique) var id: UUID = UUID()
    var userId: UUID
    var name: String
    var originalAmount: Decimal
    var interestRate: Decimal     // годовых, %
    var termMonths: Int
    var startDate: Date
    var paymentDay: Int           // число месяца оплаты (1..28)
    var monthlyPayment: Decimal   // аннуитетный платёж (хранится)
    var isArchived: Bool = false
    var isIncludedInBalance: Bool = true
    var currency: String = "RUB"
    /// nil = первый платёж через месяц после startDate (стандарт)
    var firstPaymentDate: Date? = nil

    init(userId: UUID, name: String, originalAmount: Decimal, interestRate: Decimal,
         termMonths: Int, startDate: Date, paymentDay: Int, monthlyPayment: Decimal,
         currency: String = "RUB", firstPaymentDate: Date? = nil) {
        self.userId = userId
        self.name = name
        self.originalAmount = originalAmount
        self.interestRate = interestRate
        self.termMonths = termMonths
        self.startDate = startDate
        self.paymentDay = paymentDay
        self.monthlyPayment = monthlyPayment
        self.currency = currency
        self.firstPaymentDate = firstPaymentDate
    }
}
