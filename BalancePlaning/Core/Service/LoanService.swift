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
    let date: Date           // дата отображения: для оплаченных — фактическая дата платежа, для будущих — плановая
    let scheduledDate: Date  // плановая дата слота графика (для определения логики отмены)
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
                 firstPaymentDate: Date? = nil, monthlyPaymentOverride: Decimal? = nil,
                 borrowerName: String? = nil) {
        guard let uid = currentUserId() else { return }
        let payment = monthlyPaymentOverride ?? LoanService.annuityPayment(
            principal: originalAmount, annualRate: interestRate, months: termMonths)
        let loan = Loan(userId: uid, name: name, originalAmount: originalAmount,
                        interestRate: interestRate, termMonths: termMonths,
                        startDate: startDate, paymentDay: paymentDay,
                        monthlyPayment: payment, currency: currency,
                        firstPaymentDate: firstPaymentDate, borrowerName: borrowerName)
        context.insert(loan)
        try? context.save()
    }

    func updateLoan(_ loan: Loan, name: String, interestRate: Decimal,
                    termMonths: Int, paymentDay: Int,
                    firstPaymentDate: Date? = nil, firstPaymentAmount: Decimal? = nil,
                    monthlyPaymentOverride: Decimal? = nil,
                    borrowerName: String? = nil, iconId: String? = nil) {
        loan.name = name
        loan.interestRate = interestRate
        loan.termMonths = termMonths
        loan.paymentDay = paymentDay
        loan.firstPaymentDate = firstPaymentDate
        loan.firstPaymentAmount = firstPaymentAmount
        loan.borrowerName = borrowerName
        if let iconId { loan.iconId = iconId }
        loan.monthlyPayment = monthlyPaymentOverride ?? LoanService.annuityPayment(
            principal: loan.originalAmount, annualRate: interestRate, months: termMonths)
        try? context.save()
    }

    func deleteLoan(_ loan: Loan, allPayments: [LoanPayment]) {
        let existing = (try? context.fetch(FetchDescriptor<DeletedRecord>())) ?? []
        let tombstonedIds = Set(existing.map { $0.deletedId })
        for p in allPayments where p.loanId == loan.id {
            if !tombstonedIds.contains(p.id) {
                context.insert(DeletedRecord(deletedId: p.id, userId: p.userId))
            }
            context.delete(p)
        }
        // Удаляем связанные транзакции (создаются при каждом платеже и досрочке)
        let loanId = loan.id
        let userId = loan.userId
        let txPredicate = #Predicate<Transaction> { $0.userId == userId }
        if let txs = try? context.fetch(FetchDescriptor<Transaction>(predicate: txPredicate)) {
            for tx in txs where tx.loanId == loanId {
                if !tombstonedIds.contains(tx.id) {
                    context.insert(DeletedRecord(deletedId: tx.id, userId: userId))
                }
                context.delete(tx)
            }
        }
        if !tombstonedIds.contains(loan.id) {
            context.insert(DeletedRecord(deletedId: loan.id, userId: loan.userId))
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

        // Архивируем если остаток долга равен нулю
        let updatedPayments = allPayments + [payment]
        if remainingPrincipal(for: loan, payments: updatedPayments) <= 0.01 { loan.isArchived = true }
        try? context.save()

        // После досрочного погашения обновляем запланированные будущие платежи
        if isPrepayment {
            syncFutureSchedule(for: loan, allPayments: updatedPayments)
        }
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
                              firstPaymentDate: Date?, firstPaymentAmount: Decimal? = nil,
                              monthlyPaymentOverride: Decimal?,
                              scheduledEntries: [(date: Date, amount: Decimal, isPrepayment: Bool, prepaymentType: PrepaymentType?)],
                              borrowerName: String? = nil, iconId: String = "") {
        guard let uid = currentUserId() else { return }
        let payment = monthlyPaymentOverride ?? LoanService.annuityPayment(
            principal: originalAmount, annualRate: interestRate, months: termMonths)
        let loan = Loan(userId: uid, name: name, originalAmount: originalAmount,
                        interestRate: interestRate, termMonths: termMonths,
                        startDate: startDate, paymentDay: paymentDay,
                        monthlyPayment: payment, currency: currency,
                        firstPaymentDate: firstPaymentDate, borrowerName: borrowerName)
        loan.iconId = iconId
        loan.firstPaymentAmount = firstPaymentAmount
        context.insert(loan)
        for entry in scheduledEntries {
            let note = entry.isPrepayment
                ? "Досрочное погашение: \(name)"
                : "Платёж по кредиту: \(name)"
            let lp = LoanPayment(loanId: loan.id, userId: uid, date: entry.date,
                                  totalAmount: entry.amount,
                                  isPrepayment: entry.isPrepayment,
                                  prepaymentType: entry.isPrepayment ? entry.prepaymentType : nil,
                                  fromAccountId: nil)
            context.insert(lp)
            let tx = Transaction(fromAccount: nil, userId: uid, amount: entry.amount,
                                 date: entry.date, type: .expense,
                                 note: note, loanId: loan.id)
            context.insert(tx)
        }
        try? context.save()
        // Проверка архивации
        let loanId = loan.id
        let pred = #Predicate<LoanPayment> { $0.loanId == loanId }
        if let created = try? context.fetch(FetchDescriptor<LoanPayment>(predicate: pred)) {
            if remainingPrincipal(for: loan, payments: created) <= 0.01 { loan.isArchived = true }
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

    /// Заменяет все запланированные будущие платежи кредита новым набором.
    /// Используется при редактировании графика из AddLoanSheet.
    func updateSchedule(for loan: Loan, allPayments: [LoanPayment],
                        newEntries: [(date: Date, amount: Decimal, isPrepayment: Bool, prepaymentType: PrepaymentType?)]) {
        let today = Date()
        let loanId = loan.id
        let uid = loan.userId
        let tombstones = (try? context.fetch(FetchDescriptor<DeletedRecord>())) ?? []
        let tombstonedIds = Set(tombstones.map { $0.deletedId })

        let existingFuture = allPayments
            .filter { $0.loanId == loanId && !$0.isPrepayment && $0.date > today }
        for p in existingFuture {
            deleteLinkedTransaction(loanId: loanId, userId: uid,
                                    date: p.date, amount: p.totalAmount,
                                    tombstonedIds: tombstonedIds)
            if !tombstonedIds.contains(p.id) {
                context.insert(DeletedRecord(deletedId: p.id, userId: uid))
            }
            context.delete(p)
        }

        for entry in newEntries {
            let note = entry.isPrepayment
                ? "Досрочное погашение: \(loan.name)"
                : "Платёж по кредиту: \(loan.name)"
            let lp = LoanPayment(loanId: loanId, userId: uid, date: entry.date,
                                  totalAmount: entry.amount,
                                  isPrepayment: entry.isPrepayment,
                                  prepaymentType: entry.isPrepayment ? entry.prepaymentType : nil,
                                  fromAccountId: nil)
            context.insert(lp)
            let tx = Transaction(fromAccount: nil, userId: uid, amount: entry.amount,
                                 date: entry.date, type: .expense, note: note, loanId: loanId)
            context.insert(tx)
        }
        try? context.save()
    }

    /// Пересчитывает и синхронизирует запланированные будущие LoanPayment + Transaction.
    /// Вызывается после досрочного погашения и при обнаружении несинхронизированных слотов в графике.
    func syncFutureSchedule(for loan: Loan, allPayments: [LoanPayment]) {
        let today = Date()
        let loanId = loan.id
        let uid = loan.userId

        let newSchedule = generateSchedule(for: loan, payments: allPayments)
        let futureSlots = newSchedule.filter { !$0.isPaid && !$0.isPrepayment }

        let existingFuture = allPayments
            .filter { $0.loanId == loanId && !$0.isPrepayment && $0.date > today }
            .sorted { $0.date < $1.date }

        let tombstones = (try? context.fetch(FetchDescriptor<DeletedRecord>())) ?? []
        let tombstonedIds = Set(tombstones.map { $0.deletedId })

        for (idx, existing) in existingFuture.enumerated() {
            if idx < futureSlots.count {
                let slot = futureSlots[idx]
                // Обновляем связанную транзакцию
                let predTx = #Predicate<Transaction> { $0.userId == uid }
                if let txs = try? context.fetch(FetchDescriptor<Transaction>(predicate: predTx)) {
                    for tx in txs
                    where tx.loanId == loanId
                       && Calendar.current.isDate(tx.date, inSameDayAs: existing.date)
                       && tx.amount == existing.totalAmount {
                        tx.amount = slot.totalAmount
                        tx.date = slot.date
                    }
                }
                existing.totalAmount = slot.totalAmount
                existing.date = slot.date
            } else {
                // Кредит стал короче (reduceTerm) — удаляем лишний плановый платёж
                deleteLinkedTransaction(loanId: loanId, userId: uid,
                                        date: existing.date, amount: existing.totalAmount,
                                        tombstonedIds: tombstonedIds)
                if !tombstonedIds.contains(existing.id) {
                    context.insert(DeletedRecord(deletedId: existing.id, userId: uid))
                }
                context.delete(existing)
            }
        }

        // Если нужно больше записей (кредит без предсозданного графика)
        if futureSlots.count > existingFuture.count {
            for idx in existingFuture.count..<futureSlots.count {
                let slot = futureSlots[idx]
                let lp = LoanPayment(loanId: loanId, userId: uid, date: slot.date,
                                      totalAmount: slot.totalAmount, isPrepayment: false,
                                      prepaymentType: nil, fromAccountId: nil)
                context.insert(lp)
                let tx = Transaction(fromAccount: nil, userId: uid, amount: slot.totalAmount,
                                     date: slot.date, type: .expense,
                                     note: "Платёж по кредиту: \(loan.name)", loanId: loanId)
                context.insert(tx)
            }
        }

        try? context.save()
    }

    private func deleteLinkedTransaction(loanId: UUID, userId: UUID,
                                          date: Date, amount: Decimal,
                                          tombstonedIds: Set<UUID>) {
        let predTx = #Predicate<Transaction> { $0.userId == userId }
        if let txs = try? context.fetch(FetchDescriptor<Transaction>(predicate: predTx)) {
            for tx in txs
            where tx.loanId == loanId
               && Calendar.current.isDate(tx.date, inSameDayAs: date)
               && tx.amount == amount {
                if !tombstonedIds.contains(tx.id) {
                    context.insert(DeletedRecord(deletedId: tx.id, userId: userId))
                }
                context.delete(tx)
            }
        }
    }

    // MARK: - Повторяющиеся досрочные погашения

    /// Создаёт серию повторяющихся досрочных платежей.
    /// Останавливает создание как только кредит по прогнозу будет полностью погашен.
    func addRecurringPrepayments(
        to loan: Loan,
        startDate: Date, endDate: Date,
        amount: Decimal,
        prepaymentType: PrepaymentType,
        fromAccount: Account?,
        interval: RecurringInterval,
        intervalDays: Int = 7,
        allPayments: [LoanPayment],
        comment: String = ""
    ) {
        guard let uid = currentUserId() else { return }
        let dates = Self.generateDates(from: startDate, to: endDate, interval: interval, intervalDays: intervalDays)
        guard !dates.isEmpty else { return }

        let groupId = UUID()
        var simulatedPayments = Array(allPayments)

        for date in dates {
            // Проверяем по прогнозному графику: кредит уже погашен?
            let schedule = generateSchedule(for: loan, payments: simulatedPayments)
            guard (schedule.last?.remainingAfter ?? 0) > 0.01 else { break }

            let lp = LoanPayment(loanId: loan.id, userId: uid, date: date,
                                  totalAmount: amount, isPrepayment: true,
                                  prepaymentType: prepaymentType, fromAccountId: fromAccount?.id)
            lp.recurringGroupId = groupId
            context.insert(lp)

            let tx = Transaction(fromAccount: fromAccount, userId: uid, amount: amount,
                                 date: date, type: .expense,
                                 note: "Досрочное погашение: \(loan.name)",
                                 comment: comment, loanId: loan.id)
            tx.recurringGroupId = groupId
            tx.recurringInterval = interval
            if interval == .everyNDays { tx.recurringIntervalDays = intervalDays }
            context.insert(tx)

            simulatedPayments.append(lp)

            // После добавления этого платежа кредит погашен — больше не создаём
            let updatedSchedule = generateSchedule(for: loan, payments: simulatedPayments)
            if (updatedSchedule.last?.remainingAfter ?? 0) <= 0.01 {
                loan.isArchived = true
                break
            }
        }
        try? context.save()
        syncFutureSchedule(for: loan, allPayments: simulatedPayments)
    }

    /// Удаляет все повторяющиеся досрочные платежи серии начиная с указанной даты.
    func deleteRecurringPrepayments(groupId: UUID, from date: Date, loan: Loan, allPayments: [LoanPayment]) {
        let uid = loan.userId
        let tombstones = (try? context.fetch(FetchDescriptor<DeletedRecord>())) ?? []
        let tombstonedIds = Set(tombstones.map { $0.deletedId })

        let toDelete = allPayments.filter {
            $0.recurringGroupId == groupId && $0.date >= date && $0.isPrepayment
        }
        for p in toDelete {
            deleteLinkedTransaction(loanId: loan.id, userId: uid,
                                    date: p.date, amount: p.totalAmount,
                                    tombstonedIds: tombstonedIds)
            if !tombstonedIds.contains(p.id) {
                context.insert(DeletedRecord(deletedId: p.id, userId: uid))
            }
            context.delete(p)
        }
        // Разархивируем кредит если он был закрыт этой серией
        if loan.isArchived {
            let remaining = allPayments.filter { !toDelete.map(\.id).contains($0.id) }
            if remainingPrincipal(for: loan, payments: remaining) > 0.01 {
                loan.isArchived = false
            }
        }
        try? context.save()
        let remaining = allPayments.filter { !toDelete.map(\.id).contains($0.id) }
        syncFutureSchedule(for: loan, allPayments: remaining)
    }

    private static func generateDates(from startDate: Date, to endDate: Date,
                                       interval: RecurringInterval, intervalDays: Int = 7) -> [Date] {
        var dates: [Date] = []
        var current = startDate
        while current <= endDate {
            dates.append(current)
            switch interval {
            case .daily:        current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? current
            case .everyNDays:   current = Calendar.current.date(byAdding: .day, value: intervalDays, to: current) ?? current
            case .weekly:       current = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: current) ?? current
            case .biweekly:     current = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: current) ?? current
            case .monthly:      current = Calendar.current.date(byAdding: .month, value: 1, to: current) ?? current
            }
        }
        return dates
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
        // Накопленный незакрытый процент (появляется когда досрочный/плановый платёж
        // меньше начисленных процентов за период; переходит на следующий платёж).
        var interestCarryover: Double = 0.0
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
                // Проценты накоплены за фактические дни с последнего платежа + неоплаченный остаток
                let days = cal.dateComponents([.day], from: lastDate, to: pp.date).day ?? 0
                let totalAccrued = principal * dailyRate * Double(days) + interestCarryover

                let ppAmt = LoanService.toDouble(pp.totalAmount)
                // Сначала гасятся накопленные проценты, остаток идёт в тело долга
                let interestPaid  = min(totalAccrued, ppAmt)
                let principalPaid = max(0, ppAmt - interestPaid)
                // Неоплаченная часть процентов переходит на следующий период
                interestCarryover = max(0, totalAccrued - interestPaid)
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
                    scheduledDate: pp.date,
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
            // + перенесённый остаток процентов от предыдущего периода (carryover)
            let days = cal.dateComponents([.day], from: lastDate, to: schedDate).day ?? 0
            let interest = principal * dailyRate * Double(days) + interestCarryover
            interestCarryover = 0.0

            let isPaidPayment = matched.map { $0.date <= Date() } ?? false

            // Для любого сохранённого LoanPayment (оплаченного или запланированного)
            // используем его реальную сумму. Это уважает банковские графики с нестандартными
            // периодами (напр., первый платёж через 60 дней при стандартном ежемесячном платеже).
            // Если LoanPayment отсутствует — берём сумму первого платежа от банка (слот 1) или ежемесячный.
            let fallbackPayment: Double
            if month == 1, let fp = loan.firstPaymentAmount, fp > 0 {
                fallbackPayment = LoanService.toDouble(fp)
            } else {
                fallbackPayment = currentMonthlyPayment
            }
            let effectivePayment = matched.map { LoanService.toDouble($0.totalAmount) } ?? fallbackPayment

            // Из суммы платежа сначала гасятся проценты, остаток — тело долга.
            // Если платёж меньше накопленных процентов (нестандартный первый период с 60+ днями),
            // дефицит капитализируется в тело долга — именно так поступают банки.
            var principalPart = effectivePayment - interest
            var totalPayment = effectivePayment
            if principalPart < 0 {
                principal += (-principalPart)  // дефицит процентов добавляется к долгу
                principalPart = 0
            } else if principalPart > principal {
                // Последний платёж: гасим только остаток долга + начисленный процент
                principalPart = principal
                totalPayment = principalPart + interest
            } else {
                principalPart = min(principalPart, principal)
            }
            let interestPart = totalPayment - principalPart
            principal = max(0, principal - principalPart)
            lastDate = schedDate

            // Для оплаченных платежей показываем реальную дату из LoanPayment,
            // для будущих — расчётную дату графика
            let displayDate = isPaidPayment ? (matched?.date ?? schedDate) : schedDate
            entries.append(LoanScheduleEntry(
                paymentNumber: paymentNumber,
                date: displayDate,
                scheduledDate: schedDate,
                totalAmount: Decimal(totalPayment).rounded2(),
                principalPart: Decimal(principalPart).rounded2(),
                interestPart: Decimal(interestPart).rounded2(),
                remainingAfter: Decimal(principal).rounded2(),
                isPaid: isPaidPayment,
                isPrepayment: false,
                linkedPaymentId: matched?.id
            ))
            paymentNumber += 1
            if principal <= 0.001 { break }
        }

        return entries.filter { $0.totalAmount > 0 }
    }

    /// Остаток долга — берём remainingAfter из последней оплаченной записи в графике.
    /// Этот подход корректно учитывает капитализацию процентов (напр., нестандартный первый период).
    func remainingPrincipal(for loan: Loan, payments: [LoanPayment]) -> Decimal {
        let paidToDate = payments.filter { $0.date <= Date.now }
        let schedule = generateSchedule(for: loan, payments: paidToDate)
        if let lastPaid = schedule.filter({ $0.isPaid }).last {
            return max(.zero, lastPaid.remainingAfter)
        }
        return loan.originalAmount
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
