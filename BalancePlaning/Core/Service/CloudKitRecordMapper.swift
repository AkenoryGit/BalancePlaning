//
//  CloudKitRecordMapper.swift
//  BalancePlaning
//
//  Конвертация SwiftData-моделей ↔ CKRecord для CloudKit Sharing.
//

import Foundation
import CloudKit

// MARK: - Account

extension Account {

    func update(from r: CKRecord) {
        name                = r["name"]     as? String ?? name
        if let s = r["balance"] as? String  { balance = Decimal(string: s) ?? balance }
        currency            = r["currency"] as? String ?? currency
        icon                = r["icon"]     as? String ?? icon
        isIncludedInBalance = (r["isIncludedInBalance"] as? NSNumber)?.boolValue ?? isIncludedInBalance
        if let g = r["groupId"] as? String  { groupId = g.isEmpty ? nil : UUID(uuidString: g) }
    }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(
            recordType: CloudKitConfig.RecordType.account,
            recordID: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        )
        r["id"]                  = id.uuidString
        r["userId"]              = userId.uuidString
        r["name"]                = name
        r["balance"]             = NSDecimalNumber(decimal: balance).stringValue
        r["currency"]            = currency
        r["icon"]                = icon
        r["isIncludedInBalance"] = isIncludedInBalance as NSNumber
        r["groupId"]             = groupId?.uuidString ?? ""
        return r
    }

    convenience init?(ckRecord r: CKRecord) {
        guard r.recordType == CloudKitConfig.RecordType.account,
              let idStr     = r["id"]     as? String, let id     = UUID(uuidString: idStr),
              let uidStr    = r["userId"] as? String, let userId = UUID(uuidString: uidStr),
              let name      = r["name"]   as? String,
              let balStr    = r["balance"] as? String
        else { return nil }
        let balance = Decimal(string: balStr) ?? 0
        self.init(id: id, userId: userId, name: name, balance: balance)
        currency            = r["currency"] as? String ?? "RUB"
        icon                = r["icon"]     as? String ?? ""
        isIncludedInBalance = (r["isIncludedInBalance"] as? NSNumber)?.boolValue ?? true
        if let g = r["groupId"] as? String, !g.isEmpty { groupId = UUID(uuidString: g) }
    }
}

// MARK: - AccountGroup

extension AccountGroup {

    func update(from r: CKRecord) {
        name = r["name"] as? String ?? name
    }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(
            recordType: CloudKitConfig.RecordType.accountGroup,
            recordID: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        )
        r["id"]     = id.uuidString
        r["userId"] = userId.uuidString
        r["name"]   = name
        return r
    }

    convenience init?(ckRecord r: CKRecord) {
        guard r.recordType == CloudKitConfig.RecordType.accountGroup,
              let idStr  = r["id"]     as? String, let id     = UUID(uuidString: idStr),
              let uidStr = r["userId"] as? String, let userId = UUID(uuidString: uidStr),
              let name   = r["name"]   as? String
        else { return nil }
        self.init(id: id, userId: userId, name: name)
    }
}

// MARK: - Category

extension Category {

    func update(from r: CKRecord) {
        name      = r["name"]  as? String ?? name
        if let s = r["type"] as? String, let t = CategoryType(rawValue: s) { type = t }
        isDefault = (r["isDefault"] as? NSNumber)?.boolValue ?? isDefault
        color     = r["color"] as? String ?? color
        icon      = r["icon"]  as? String ?? icon
        if let p  = r["parentId"] as? String { parentId = p.isEmpty ? nil : UUID(uuidString: p) }
    }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(
            recordType: CloudKitConfig.RecordType.category,
            recordID: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        )
        r["id"]        = id.uuidString
        r["userId"]    = userId.uuidString
        r["name"]      = name
        r["type"]      = type.rawValue
        r["parentId"]  = parentId?.uuidString ?? ""
        r["isDefault"] = isDefault as NSNumber
        r["color"]     = color
        r["icon"]      = icon
        return r
    }

    convenience init?(ckRecord r: CKRecord) {
        guard r.recordType == CloudKitConfig.RecordType.category,
              let idStr   = r["id"]     as? String, let id     = UUID(uuidString: idStr),
              let uidStr  = r["userId"] as? String, let userId = UUID(uuidString: uidStr),
              let name    = r["name"]   as? String,
              let typeStr = r["type"]   as? String, let type   = CategoryType(rawValue: typeStr)
        else { return nil }
        self.init(id: id, userId: userId, name: name, type: type)
        isDefault = (r["isDefault"] as? NSNumber)?.boolValue ?? false
        color     = r["color"] as? String ?? ""
        icon      = r["icon"]  as? String ?? ""
        if let p = r["parentId"] as? String, !p.isEmpty { parentId = UUID(uuidString: p) }
    }
}

// MARK: - Transaction

extension Transaction {

    func update(from r: CKRecord, accounts: [Account], categories: [Category]) {
        func findAccount(_ key: String) -> Account? {
            guard let s = r[key] as? String, !s.isEmpty, let id = UUID(uuidString: s) else { return nil }
            return accounts.first { $0.id == id }
        }
        func findCategory(_ key: String) -> Category? {
            guard let s = r[key] as? String, !s.isEmpty, let id = UUID(uuidString: s) else { return nil }
            return categories.first { $0.id == id }
        }
        func uuidOrNil(_ key: String) -> UUID? {
            guard let s = r[key] as? String, !s.isEmpty else { return nil }
            return UUID(uuidString: s)
        }
        if let s = r["amount"] as? String, let d = Decimal(string: s) { amount = d }
        if let d = r["date"]   as? Date                                { date   = d }
        if let s = r["type"]   as? String, let t = TransactionType(rawValue: s) { type = t }
        note         = r["note"]    as? String ?? note
        comment      = r["comment"] as? String ?? comment
        fromAccount  = findAccount("fromAccountId")
        toAccount    = findAccount("toAccountId")
        fromCategory = findCategory("fromCategoryId")
        toCategory   = findCategory("toCategoryId")
        loanId       = uuidOrNil("loanId")
        recurringGroupId = uuidOrNil("recurringGroupId")
        let intervalStr  = r["recurringInterval"] as? String ?? ""
        recurringInterval     = intervalStr.isEmpty ? nil : RecurringInterval(rawValue: intervalStr)
        let iDays             = (r["recurringIntervalDays"] as? NSNumber)?.intValue
        recurringIntervalDays = (iDays == 0 ? nil : iDays)
        let priorityStr = r["priority"] as? String ?? ""
        priority        = priorityStr.isEmpty ? nil : TransactionPriority(rawValue: priorityStr)
        let toAmtStr = r["toAmount"] as? String ?? ""
        toAmount     = toAmtStr.isEmpty ? nil : Decimal(string: toAmtStr)
        let creatorStr = r["creatorName"] as? String ?? ""
        creatorName    = creatorStr.isEmpty ? nil : creatorStr
    }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(
            recordType: CloudKitConfig.RecordType.transaction,
            recordID: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        )
        r["id"]                   = id.uuidString
        r["userId"]               = userId.uuidString
        r["amount"]               = NSDecimalNumber(decimal: amount).stringValue
        r["date"]                 = date as NSDate
        r["type"]                 = type.rawValue
        r["note"]                 = note
        r["comment"]              = comment
        r["fromAccountId"]        = fromAccount?.id.uuidString  ?? ""
        r["toAccountId"]          = toAccount?.id.uuidString    ?? ""
        r["fromCategoryId"]       = fromCategory?.id.uuidString ?? ""
        r["toCategoryId"]         = toCategory?.id.uuidString   ?? ""
        r["loanId"]               = loanId?.uuidString          ?? ""
        r["recurringGroupId"]     = recurringGroupId?.uuidString ?? ""
        r["recurringInterval"]    = recurringInterval?.rawValue  ?? ""
        r["recurringIntervalDays"] = (recurringIntervalDays ?? 0) as NSNumber
        r["priority"]             = priority?.rawValue ?? ""
        r["toAmount"]             = toAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        r["creatorName"]          = creatorName ?? ""
        return r
    }

    /// Создаёт Transaction из CKRecord, подставляя ссылки на Account/Category из переданных массивов.
    convenience init?(ckRecord r: CKRecord, accounts: [Account], categories: [Category]) {
        guard r.recordType == CloudKitConfig.RecordType.transaction,
              let idStr   = r["id"]     as? String, let id     = UUID(uuidString: idStr),
              let uidStr  = r["userId"] as? String, let userId = UUID(uuidString: uidStr),
              let amtStr  = r["amount"] as? String,
              let date    = r["date"]   as? Date,
              let typeStr = r["type"]   as? String, let type   = TransactionType(rawValue: typeStr)
        else { return nil }

        let amount = Decimal(string: amtStr) ?? 0

        func findAccount(_ key: String) -> Account? {
            guard let s = r[key] as? String, !s.isEmpty, let id = UUID(uuidString: s) else { return nil }
            return accounts.first { $0.id == id }
        }
        func findCategory(_ key: String) -> Category? {
            guard let s = r[key] as? String, !s.isEmpty, let id = UUID(uuidString: s) else { return nil }
            return categories.first { $0.id == id }
        }
        func uuidOrNil(_ key: String) -> UUID? {
            guard let s = r[key] as? String, !s.isEmpty else { return nil }
            return UUID(uuidString: s)
        }

        let toAmtStr = r["toAmount"] as? String ?? ""
        let toAmount = toAmtStr.isEmpty ? nil : Decimal(string: toAmtStr)

        let intervalStr = r["recurringInterval"] as? String ?? ""
        let interval    = intervalStr.isEmpty ? nil : RecurringInterval(rawValue: intervalStr)
        let iDays       = (r["recurringIntervalDays"] as? NSNumber)?.intValue
        let priorityStr = r["priority"] as? String ?? ""
        let priority    = priorityStr.isEmpty ? nil : TransactionPriority(rawValue: priorityStr)

        let creatorStr = r["creatorName"] as? String ?? ""
        self.init(
            id:                    id,
            fromAccount:           findAccount("fromAccountId"),
            fromCategory:          findCategory("fromCategoryId"),
            toAccount:             findAccount("toAccountId"),
            toCategory:            findCategory("toCategoryId"),
            userId:                userId,
            amount:                amount,
            toAmount:              toAmount,
            date:                  date,
            type:                  type,
            priority:              priority,
            recurringGroupId:      uuidOrNil("recurringGroupId"),
            recurringInterval:     interval,
            recurringIntervalDays: (iDays == 0 ? nil : iDays),
            note:                  r["note"]    as? String ?? "",
            comment:               r["comment"] as? String ?? "",
            loanId:                uuidOrNil("loanId"),
            creatorName:           creatorStr.isEmpty ? nil : creatorStr
        )
    }
}

// MARK: - Loan

extension Loan {

    func update(from r: CKRecord) {
        name     = r["name"] as? String ?? name
        currency = r["currency"] as? String ?? currency
        if let s = r["originalAmount"]  as? String  { originalAmount  = Decimal(string: s) ?? originalAmount  }
        if let s = r["interestRate"]    as? String  { interestRate    = Decimal(string: s) ?? interestRate    }
        if let s = r["monthlyPayment"]  as? String  { monthlyPayment  = Decimal(string: s) ?? monthlyPayment  }
        if let n = r["termMonths"]  as? NSNumber    { termMonths      = n.intValue }
        if let d = r["startDate"]   as? Date        { startDate       = d }
        if let n = r["paymentDay"]  as? NSNumber    { paymentDay      = n.intValue }
        isArchived          = (r["isArchived"]          as? NSNumber)?.boolValue ?? isArchived
        isIncludedInBalance = (r["isIncludedInBalance"] as? NSNumber)?.boolValue ?? isIncludedInBalance
        if let d = r["firstPaymentDate"] as? Date, d.timeIntervalSince1970 > 0 { firstPaymentDate = d }
    }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(
            recordType: CloudKitConfig.RecordType.loan,
            recordID: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        )
        r["id"]                  = id.uuidString
        r["userId"]              = userId.uuidString
        r["name"]                = name
        r["originalAmount"]      = NSDecimalNumber(decimal: originalAmount).stringValue
        r["interestRate"]        = NSDecimalNumber(decimal: interestRate).stringValue
        r["termMonths"]          = termMonths as NSNumber
        r["startDate"]           = startDate as NSDate
        r["paymentDay"]          = paymentDay as NSNumber
        r["monthlyPayment"]      = NSDecimalNumber(decimal: monthlyPayment).stringValue
        r["isArchived"]          = isArchived as NSNumber
        r["isIncludedInBalance"] = isIncludedInBalance as NSNumber
        r["currency"]            = currency
        r["firstPaymentDate"]    = firstPaymentDate as NSDate? ?? NSDate(timeIntervalSince1970: 0)
        return r
    }

    convenience init?(ckRecord r: CKRecord) {
        guard r.recordType == CloudKitConfig.RecordType.loan,
              let idStr   = r["id"]             as? String, let id     = UUID(uuidString: idStr),
              let uidStr  = r["userId"]          as? String, let userId = UUID(uuidString: uidStr),
              let name    = r["name"]            as? String,
              let origStr = r["originalAmount"]  as? String,
              let rateStr = r["interestRate"]    as? String,
              let termN   = r["termMonths"]      as? NSNumber,
              let startD  = r["startDate"]       as? Date,
              let dayN    = r["paymentDay"]      as? NSNumber,
              let moStr   = r["monthlyPayment"]  as? String
        else { return nil }

        self.init(
            userId: userId,
            name: name,
            originalAmount: Decimal(string: origStr) ?? 0,
            interestRate:   Decimal(string: rateStr) ?? 0,
            termMonths:     termN.intValue,
            startDate:      startD,
            paymentDay:     dayN.intValue,
            monthlyPayment: Decimal(string: moStr)   ?? 0
        )
        self.id                  = id
        currency                 = r["currency"]            as? String ?? "RUB"
        isArchived               = (r["isArchived"]          as? NSNumber)?.boolValue ?? false
        isIncludedInBalance      = (r["isIncludedInBalance"] as? NSNumber)?.boolValue ?? true
        if let d = r["firstPaymentDate"] as? Date,
           d.timeIntervalSince1970 > 0 { firstPaymentDate = d }
    }
}

// MARK: - LoanPayment

extension LoanPayment {

    func update(from r: CKRecord) {
        if let d = r["date"]        as? Date   { date        = d }
        if let s = r["totalAmount"] as? String { totalAmount = Decimal(string: s) ?? totalAmount }
        isPrepayment = (r["isPrepayment"] as? NSNumber)?.boolValue ?? isPrepayment
        let ppStr    = r["prepaymentType"] as? String ?? ""
        prepaymentType = ppStr.isEmpty ? nil : PrepaymentType(rawValue: ppStr)
        let accStr   = r["fromAccountId"] as? String ?? ""
        fromAccountId = accStr.isEmpty ? nil : UUID(uuidString: accStr)
    }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(
            recordType: CloudKitConfig.RecordType.loanPayment,
            recordID: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        )
        r["id"]             = id.uuidString
        r["loanId"]         = loanId.uuidString
        r["userId"]         = userId.uuidString
        r["date"]           = date as NSDate
        r["totalAmount"]    = NSDecimalNumber(decimal: totalAmount).stringValue
        r["isPrepayment"]   = isPrepayment as NSNumber
        r["prepaymentType"] = prepaymentType?.rawValue ?? ""
        r["fromAccountId"]  = fromAccountId?.uuidString ?? ""
        return r
    }

    convenience init?(ckRecord r: CKRecord) {
        guard r.recordType == CloudKitConfig.RecordType.loanPayment,
              let idStr    = r["id"]          as? String, let id     = UUID(uuidString: idStr),
              let loanStr  = r["loanId"]      as? String, let loanId = UUID(uuidString: loanStr),
              let uidStr   = r["userId"]      as? String, let userId = UUID(uuidString: uidStr),
              let date     = r["date"]        as? Date,
              let amtStr   = r["totalAmount"] as? String
        else { return nil }

        let ppTypeStr = r["prepaymentType"] as? String ?? ""
        let ppType    = ppTypeStr.isEmpty ? nil : PrepaymentType(rawValue: ppTypeStr)
        let accStr    = r["fromAccountId"] as? String ?? ""

        self.init(
            loanId:         loanId,
            userId:         userId,
            date:           date,
            totalAmount:    Decimal(string: amtStr) ?? 0,
            isPrepayment:   (r["isPrepayment"] as? NSNumber)?.boolValue ?? false,
            prepaymentType: ppType,
            fromAccountId:  accStr.isEmpty ? nil : UUID(uuidString: accStr)
        )
        self.id = id
    }
}

// MARK: - DeletedRecord (tombstone)

extension DeletedRecord {

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        // Имя записи = "tombstone-<deletedId>" — один tombstone на объект, идемпотентно
        let r = CKRecord(
            recordType: CloudKitConfig.RecordType.deletedRecord,
            recordID: CKRecord.ID(recordName: "tombstone-\(deletedId.uuidString)", zoneID: zoneID)
        )
        r["deletedId"] = deletedId.uuidString
        r["deletedAt"] = deletedAt as NSDate
        r["userId"]    = userId.uuidString
        return r
    }

    convenience init?(ckRecord r: CKRecord) {
        guard r.recordType == CloudKitConfig.RecordType.deletedRecord,
              let didStr = r["deletedId"] as? String, let deletedId = UUID(uuidString: didStr),
              let uidStr = r["userId"]    as? String, let userId    = UUID(uuidString: uidStr)
        else { return nil }
        self.init(deletedId: deletedId, userId: userId)
        if let d = r["deletedAt"] as? Date { self.deletedAt = d }
    }
}

// MARK: - Currency

extension Currency {

    func update(from r: CKRecord) {
        code   = r["code"]   as? String ?? code
        symbol = r["symbol"] as? String ?? symbol
        name   = r["name"]   as? String ?? name
    }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(
            recordType: CloudKitConfig.RecordType.currency,
            recordID: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        )
        r["id"]     = id.uuidString
        r["userId"] = userId.uuidString
        r["code"]   = code
        r["symbol"] = symbol
        r["name"]   = name
        return r
    }

    convenience init?(ckRecord r: CKRecord) {
        guard r.recordType == CloudKitConfig.RecordType.currency,
              let idStr  = r["id"]     as? String, let id     = UUID(uuidString: idStr),
              let uidStr = r["userId"] as? String, let userId = UUID(uuidString: uidStr),
              let code   = r["code"]   as? String,
              let symbol = r["symbol"] as? String,
              let name   = r["name"]   as? String
        else { return nil }
        self.init(id: id, userId: userId, code: code, symbol: symbol, name: name)
    }
}
