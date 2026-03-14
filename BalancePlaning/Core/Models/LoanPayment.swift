//
//  LoanPayment.swift
//  BalancePlaning
//

import Foundation
import SwiftData

enum PrepaymentType: String, Codable {
    case reduceTerm     // уменьшение срока
    case reducePayment  // уменьшение ежемесячного платежа
}

@Model
class LoanPayment {
    @Attribute(.unique) var id: UUID = UUID()
    var loanId: UUID
    var userId: UUID
    var date: Date
    var totalAmount: Decimal
    var isPrepayment: Bool = false
    var prepaymentType: PrepaymentType? = nil
    var fromAccountId: UUID? = nil

    init(loanId: UUID, userId: UUID, date: Date, totalAmount: Decimal,
         isPrepayment: Bool = false, prepaymentType: PrepaymentType? = nil,
         fromAccountId: UUID? = nil) {
        self.loanId = loanId
        self.userId = userId
        self.date = date
        self.totalAmount = totalAmount
        self.isPrepayment = isPrepayment
        self.prepaymentType = prepaymentType
        self.fromAccountId = fromAccountId
    }
}
