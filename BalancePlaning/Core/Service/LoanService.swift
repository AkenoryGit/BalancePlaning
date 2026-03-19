//
//  LoanService.swift
//  BalancePlaning
//

import Foundation
import SwiftData

// MARK: - Запись в графике платежей

struct LoanScheduleEntry: Identifiable {
    let id = UUID()
    let paymentNumber: Int
    let date: Date
    let totalAmount: Decimal
    let principalPart: Decimal
    let interestPart: Decimal
    let remainingAfter: Decimal
    let isPaid: Bool
    let isPrepayment: Bool
    let linkedPaymentId: UUID?
}

// MARK: - Сервис кредитов

struct LoanService {
    let context: ModelContext

    // MARK: - CRUD

    func addLoan(name: String, originalAmount: Decimal, interestRate: Decimal,
                 termMonths: Int, startDate: Date, paymentDay: Int, currency: String = "RUB",
                 firstPaymentDate: Date? = nil, monthlyPaymentOverride: Decimal? = nil) {
        guard let uid = currentUserId() else { return }
        let payment = monthlyPaymentOverride ?? LoanService.annuityPayment(
            principal: originalAmount, annualRate: interestRate, months: termMonths)
        let loan = Loan(userId: uid, name: name, originalAmount: originalAmount,
                        interestRate: interestRate, termMonths: termMonths,
                        startDate: startDate, paymentDay: paymentDay,
                        monthlyPayment: payment, currency: currency,
                        firstPaymentDate: firstPaymentDate)
        context.insert(loan)
        try? context.save()
    }

    func updateLoan(_ loan: Loan, name: String, interestRate: Decimal,
                    termMonths: Int, paymentDay: Int,
                    firstPaymentDate: Date? = nil, monthlyPaymentOverride: Decimal? = nil) {
        loan.name = name
        loan.interestRate = interestRate
        loan.termMonths = termMonths
        loan.paymentDay = paymentDay
        loan.firstPaymentDate = firstPaymentDate
        loan.monthlyPayment = monthlyPaymentOverride ?? LoanService.annuityPayment(
            principal: loan.originalAmount, annualRate: interestRate, months: termMonths)
        try? context.save()
    }

    func deleteLoan(_ loan: Loan, allPayments: [LoanPayment]) {
        for p in allPayments where p.loanId == loan.id {
            context.delete(p)
        }
        context.delete(loan)
        try? context.save()
    }

    func addPayment(to loan: Loan, date: Date, amount: Decimal,
                    isPrepayment: Bool, prepaymentType: PrepaymentType?,
                    fromAccount: Account?, allPayments: [LoanPayment],
                    comment: String = "") {
        guard let uid = currentUserId() else { return }
        let payment = LoanPayment(loanId: loan.id, userId: uid, date: date,
                                   totalAmount: amount, isPrepayment: isPrepayment,
                                   prepaymentType: prepaymentType,
                                   fromAccountId: fromAccount?.id)
        context.insert(payment)

        let txNote = isPrepayment
            ? "Досрочное погашение: \(loan.name)"
            : "Платёж по кредиту: \(loan.name)"
        let tx = Transaction(
            fromAccount: fromAccount,
            userId: uid,
            amount: amount,
            date: date,
            type: .expense,
            note: txNote,
            comment: comment,
            loanId: loan.id
        )
        context.insert(tx)

        // Архивируем если фактически погашен весь основной долг
        let updatedPayments = allPayments + [payment]
        let schedule = generateSchedule(for: loan, payments: updatedPayments)
        let paidPrincipal = schedule.filter { $0.isPaid }.reduce(Decimal.zero) { $0 + $1.principalPart }
        if loan.originalAmount - paidPrincipal <= 0.01 { loan.isArchived = true }
        try? context.save()
    }

    func deletePayment(_ payment: LoanPayment, loan: Loan, allPayments: [LoanPayment]) {
        let loanId       = payment.loanId
        let paymentDate  = payment.date
        let paymentAmount = payment.totalAmount
        let userId       = payment.userId

        // Удаляем связанную Transaction
        let txPredicate = #Predicate<Transaction> { $0.userId == userId }
        if let txs = try? context.fetch(FetchDescriptor<Transaction>(predicate: txPredicate)) {
            for tx in txs
            where tx.loanId == loanId
               && Calendar.current.isDate(tx.date, inSameDayAs: paymentDate)
               && tx.amount == paymentAmount {
                context.delete(tx)
            }
        }

        context.delete(payment)

        // Если кредит был закрыт — проверяем, не нужно ли его разархивировать
        if loan.isArchived {
            let remaining = allPayments.filter { $0.id != payment.id }
            if remainingPrincipal(for: loan, payments: remaining) > 0.01 {
                loan.isArchived = false
            }
        }

        try? context.save()
    }

    /// Создаёт кредит и сразу все запланированные платежи (операции).
    func addLoanWithSchedule(name: String, originalAmount: Decimal, interestRate: Decimal,
                              termMonths: Int, startDate: Date, paymentDay: Int, currency: String,
                              firstPaymentDate: Date?, monthlyPaymentOverride: Decimal?,
                              scheduledEntries: [(date: Date, amount: Decimal)]) {
        guard let uid = currentUserId() else { return }
        let payment = monthlyPaymentOverride ?? LoanService.annuityPayment(
            principal: originalAmount, annualRate: interestRate, months: termMonths)
        let loan = Loan(userId: uid, name: name, originalAmount: originalAmount,
                        interestRate: interestRate, termMonths: termMonths,
                        startDate: startDate, paymentDay: paymentDay,
                        monthlyPayment: payment, currency: currency,
                        firstPaymentDate: firstPaymentDate)
        context.insert(loan)
        for entry in scheduledEntries {
            let lp = LoanPayment(loanId: loan.id, userId: uid, date: entry.date,
                                  totalAmount: entry.amount, isPrepayment: false,
                                  prepaymentType: nil, fromAccountId: nil)
            context.insert(lp)
            let tx = Transaction(fromAccount: nil, userId: uid, amount: entry.amount,
                                 date: entry.date, type: .expense,
                                 note: "Платёж по кредиту: \(name)", loanId: loan.id)
            context.insert(tx)
        }
        try? context.save()
        // Проверка архивации
        let loanId = loan.id
        let pred = #Predicate<LoanPayment> { $0.loanId == loanId }
        if let created = try? context.fetch(FetchDescriptor<LoanPayment>(predicate: pred)) {
            let schedule = generateSchedule(for: loan, payments: created)
            let paidPrincipal = schedule.filter { $0.isPaid }.reduce(Decimal.zero) { $0 + $1.principalPart }
            if loan.originalAmount - paidPrincipal <= 0.01 { loan.isArchived = true }
            try? context.save()
        }
    }

    /// Меняет дату платежа и связанной транзакции
    func revertPaymentDate(_ payment: LoanPayment, to date: Date) {
        let loanId = payment.loanId
        let currentDate = payment.date
        let amount = payment.totalAmount
        let userId = payment.userId
        let predicate = #Predicate<Transaction> { $0.userId == userId }
        if let txs = try? context.fetch(FetchDescriptor<Transaction>(predicate: predicate)) {
            for tx in txs where tx.loanId == loanId
                && Calendar.current.isDate(tx.date, inSameDayAs: currentDate)
                && tx.amount == amount {
                tx.date = date
            }
        }
        payment.date = date
        try? context.save()
    }

    // MARK: - Расчёты

    static func annuityPayment(principal: Decimal, annualRate: Decimal, months: Int) -> Decimal {
        guard months > 0 else { return .zero }
        if annualRate == .zero {
            return (principal / Decimal(months)).rounded2()
        }
        let r = toDouble(annualRate) / 100.0 / 12.0
        let p = toDouble(principal)
        let n = Double(months)
        let m = p * r / (1.0 - pow(1.0 + r, -n))
        return Decimal(m).rounded2()
    }

    func generateSchedule(for loan: Loan, payments: [LoanPayment]) -> [LoanScheduleEntry] {
        let sorted = payments.filter { $0.loanId == loan.id }.sorted { $0.date < $1.date }

        var prepaymentQueue = sorted.filter { $0.isPrepayment }
        var regularQueue    = sorted.filter { !$0.isPrepayment }

        // Российские банки начисляют проценты по фактическим дням: ставка / 365
        let annualRate = LoanService.toDouble(loan.interestRate) / 100.0
        let dailyRate  = annualRate / 365.0
        // Для пересчёта платежа после досрочного (reducePayment) используем annual/12 — стандарт банков
        let monthlyRate = annualRate / 12.0

        var principal = LoanService.toDouble(loan.originalAmount)
        var currentMonthlyPayment = LoanService.toDouble(loan.monthlyPayment)

        var entries: [LoanScheduleEntry] = []
        var paymentNumber = 1
        // Дата последнего события — с неё считаем накопленные проценты
        var lastDate = loan.startDate

        let cal = Calendar.current

        for month in 1...600 {
            guard principal > 0.001 else { break }

            let schedDate = paymentDate(for: loan, month: month)
            let prevDate  = month == 1 ? loan.startDate : paymentDate(for: loan, month: month - 1)

            // Досрочные платежи в окне (prevDate, schedDate]
            let prepays = prepaymentQueue.filter { $0.date > prevDate && $0.date <= schedDate }
            prepaymentQueue.removeAll { prepays.map(\.id).contains($0.id) }

            for pp in prepays {
                // Проценты накоплены за фактические дни с последнего платежа
                let days = cal.dateComponents([.day], from: lastDate, to: pp.date).day ?? 0
                let accruedInterest = principal * dailyRate * Double(days)

                let ppAmt = LoanService.toDouble(pp.totalAmount)
                // Сначала гасятся накопленные проценты, остаток идёт в тело долга
                let interestPaid  = min(accruedInterest, ppAmt)
                let principalPaid = max(0, ppAmt - interestPaid)
                principal = max(0, principal - principalPaid)
                lastDate = pp.date

                if pp.prepaymentType == .reducePayment {
                    let rem = LoanService.estimateMonths(principal: principal, payment: currentMonthlyPayment, r: monthlyRate)
                    if rem > 0 && monthlyRate > 0 {
                        currentMonthlyPayment = principal * monthlyRate / (1.0 - pow(1.0 + monthlyRate, -Double(rem)))
                    } else if rem > 0 {
                        currentMonthlyPayment = principal / Double(rem)
                    }
                }

                entries.append(LoanScheduleEntry(
                    paymentNumber: paymentNumber,
                    date: pp.date,
                    totalAmount: pp.totalAmount,
                    principalPart: Decimal(principalPaid).rounded2(),
                    interestPart: Decimal(interestPaid).rounded2(),
                    remainingAfter: Decimal(principal).rounded2(),
                    isPaid: true,
                    isPrepayment: true,
                    linkedPaymentId: pp.id
                ))
                paymentNumber += 1
                if principal <= 0.001 { break }
            }

            guard principal > 0.001 else { break }

            // Плановый платёж — ищем в окне (prevDate, schedDate] по дате
            let matchedIndex = regularQueue.firstIndex(where: { $0.date > prevDate && $0.date <= schedDate })
            let matched = matchedIndex.map { regularQueue.remove(at: $0) }

            // Проценты за фактические дни с последнего платежа/досрочки до даты платежа
            let days = cal.dateComponents([.day], from: lastDate, to: schedDate).day ?? 0
            let interest = principal * dailyRate * Double(days)

            var principalPart = currentMonthlyPayment - interest
            principalPart = max(0, min(principalPart, principal))
            let totalPaid = principalPart + interest
            principal = max(0, principal - principalPart)
            lastDate = schedDate

            entries.append(LoanScheduleEntry(
                paymentNumber: paymentNumber,
                date: schedDate,
                totalAmount: Decimal(totalPaid).rounded2(),
                principalPart: Decimal(principalPart).rounded2(),
                interestPart: Decimal(interest).rounded2(),
                remainingAfter: Decimal(principal).rounded2(),
                isPaid: matched.map { $0.date <= Date() } ?? false,
                isPrepayment: false,
                linkedPaymentId: matched?.id
            ))
            paymentNumber += 1
            if principal <= 0.001 { break }
        }

        return entries.filter { $0.totalAmount > 0 }
    }

    /// Остаток долга — сумма principalPart по фактически оплаченным записям (≤ сегодня).
    func remainingPrincipal(for loan: Loan, payments: [LoanPayment]) -> Decimal {
        let paidToDate = payments.filter { $0.date <= Date.now }
        let schedule = generateSchedule(for: loan, payments: paidToDate)
        let paidPrincipal = schedule.filter { $0.isPaid }.reduce(Decimal.zero) { $0 + $1.principalPart }
        return max(.zero, loan.originalAmount - paidPrincipal)
    }

    /// Текущий плановый платёж — на основе платежей ≤ сегодня.
    func currentMonthlyPayment(for loan: Loan, payments: [LoanPayment]) -> Decimal {
        let paidToDate = payments.filter { $0.date <= Date.now }
        let schedule = generateSchedule(for: loan, payments: paidToDate)
        return schedule.first(where: { !$0.isPaid && !$0.isPrepayment })?.totalAmount ?? loan.monthlyPayment
    }

    /// Оставшиеся месяцы — на основе платежей ≤ сегодня.
    func remainingMonths(for loan: Loan, payments: [LoanPayment]) -> Int {
        let paidToDate = payments.filter { $0.date <= Date.now }
        let schedule = generateSchedule(for: loan, payments: paidToDate)
        return schedule.filter { !$0.isPaid && !$0.isPrepayment }.count
    }

    /// Дата следующего платежа — на основе платежей ≤ сегодня.
    func nextPaymentDate(for loan: Loan, payments: [LoanPayment]) -> Date? {
        let paidToDate = payments.filter { $0.date <= Date.now }
        let schedule = generateSchedule(for: loan, payments: paidToDate)
        return schedule.first(where: { !$0.isPaid && !$0.isPrepayment })?.date
    }

    /// Суммарная оставшаяся стоимость — на основе платежей ≤ сегодня.
    func totalRemainingCost(for loan: Loan, payments: [LoanPayment]) -> Decimal {
        let paidToDate = payments.filter { $0.date <= Date.now }
        let schedule = generateSchedule(for: loan, payments: paidToDate)
        return schedule.filter { !$0.isPaid }.reduce(.zero) { $0 + $1.totalAmount }
    }

    func totalOverpayment(for loan: Loan, payments: [LoanPayment]) -> Decimal {
        let remaining = remainingPrincipal(for: loan, payments: payments)
        let totalCost = totalRemainingCost(for: loan, payments: payments)
        return totalCost - remaining
    }

    // MARK: - Private helpers

    func paymentDate(for loan: Loan, month: Int) -> Date {
        let cal = Calendar.current
        // Дата первого платежа: явно заданная или через месяц после выдачи
        let firstDate: Date
        if let explicit = loan.firstPaymentDate {
            firstDate = explicit
        } else {
            var comps = cal.dateComponents([.year, .month], from: loan.startDate)
            comps.month = (comps.month ?? 1) + 1
            firstDate = LoanService.resolvedDate(paymentDay: loan.paymentDay, comps: comps, cal: cal) ?? loan.startDate
        }
        if month == 1 { return firstDate }
        // Последующие месяцы: +N месяцев от первого платежа
        var comps = cal.dateComponents([.year, .month], from: firstDate)
        comps.month = (comps.month ?? 1) + (month - 1)
        return LoanService.resolvedDate(paymentDay: loan.paymentDay, comps: comps, cal: cal) ?? loan.startDate
    }

    /// paymentDay == 0 → последний день месяца; иначе min(paymentDay, 28)
    private static func resolvedDate(paymentDay: Int, comps: DateComponents, cal: Calendar) -> Date? {
        var c = comps
        if paymentDay == 0 {
            c.day = 1
            guard let firstOfMonth = cal.date(from: c),
                  let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
            c.day = range.upperBound - 1
        } else {
            c.day = min(paymentDay, 28)
        }
        return cal.date(from: c)
    }

    private static func estimateMonths(principal: Double, payment: Double, r: Double) -> Int {
        guard r > 0, payment > principal * r else { return max(1, Int(ceil(principal / max(payment, 1)))) }
        let n = -log(1.0 - r * principal / payment) / log(1.0 + r)
        return max(1, Int(ceil(n)))
    }

    static func toDouble(_ d: Decimal) -> Double {
        Double(truncating: NSDecimalNumber(decimal: d))
    }
}

private extension Decimal {
    func rounded2() -> Decimal {
        var d = self
        var result = Decimal()
        NSDecimalRound(&result, &d, 2, .plain)
        return result
    }
}
