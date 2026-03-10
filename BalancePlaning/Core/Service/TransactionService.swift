//
//  TransactionService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI
import SwiftData

struct TransactionService {
    @Query(sort: \Account.userId) var accounts:[Account] = []
    @Query(sort: \Category.userId) var categories:[Category] = []
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func addTransactions(from: Account, to: Account, amount: Decimal, date: Date) {
        guard let curUserID = currentUserId() else {
            print("Пользователь не найден")
            return
        }
        let newTransaction = Transaction(
            fromAccount: from,
            toAccount: to,
            userId: curUserID,
            amount: amount,
            date: date,
            type: .transaction
        )
        
        context.insert(newTransaction)
        
        do {
            try context.save()
            print("Перевод \(newTransaction) был успешно создан!")
        } catch {
            print("Ошибка создания перевода: \(error)")
            context.delete(newTransaction)
        }
    }
    
    func addExpenense(from: Account, to: Category, amount: Decimal, date: Date) {
        guard let curUserID = currentUserId() else {
            print("Пользователь не найден")
            return
        }
        let newExpense = Transaction(
            fromAccount: from,
            toCategory: to,
            userId: curUserID,
            amount: amount,
            date: date,
            type: .expense
        )
        
        context.insert(newExpense)
        
        do {
            try context.save()
            print("Расход \(newExpense) был успешно создан!")
        } catch {
            print("Ошибка создания расхода: \(error)")
            context.delete(newExpense)
        }
    }
    
    func addIncome(from: Category, to: Account, amount: Decimal, date: Date) {
        guard let curUserID = currentUserId() else {
            print("Пользователь не найден")
            return
        }
        let newIncome = Transaction(
            fromCategory: from,
            toAccount: to,
            userId: curUserID,
            amount: amount,
            date: date,
            type: .income
        )
        
        context.insert(newIncome)
        
        do {
            try context.save()
            print("Поступление \(newIncome) было успешно создано!")
        } catch {
            print("Ошибка создания поступления: \(error)")
            context.delete(newIncome)
        }
    }
}
