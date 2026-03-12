# BalancePlaning

Личное iOS-приложение для учёта финансов. Счета, доходы, расходы, переводы между счётами, повторяющиеся операции, аналитика по месяцам. Разрабатывается одним разработчиком в учебных целях.

## Overview

- **Платформа:** iOS, Xcode 26.2, deployment target iOS 26.2
- **UI:** SwiftUI (100%), нет UIKit
- **Хранилище:** SwiftData (`@Model`, `ModelContext`, `@Query`)
- **Архитектура:** Feature-модули + Service layer. Нет MVVM/TCA — логика в сервисах (`XxxService`), View содержат только UI-состояние
- **Swift Concurrency:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` включён глобально. async/await не используется (только `Task { @MainActor in }` в редких местах)
- **Внешние зависимости:** отсутствуют (нет SPM, нет CocoaPods)
- **Авторизация:** пароли в Keychain (`KeychainManager`), session-UUID в `UserDefaults`
- **Charts:** встроенный фреймворк Swift Charts (AnalyticsView)

## Key Directories & Files

```
BalancePlaning/
├── App/
│   ├── BalancePlaningApp.swift   — точка входа, ModelContainer с защитой от сбоя миграции
│   └── ContentView.swift          — TabView: auth / регистрация / основной контент
├── Core/
│   ├── Models/                    — @Model классы: User, Account, Category, Transaction
│   ├── Service/                   — сервисы: UserService, AccountService, CategoryService, TransactionService
│   └── Keychain/KeychainManager.swift — сохранение/чтение пароля из Keychain
├── DesignSystem/
│   ├── AppTheme.swift             — цвета, cardStyle(), SummaryPill, расширения TransactionType
│   └── Components/                — CustomSecureField, Header, TopHead
├── Features/
│   ├── AutorizationView/          — вход и регистрация
│   ├── ProfileView/               — ProfileView, AccountsView, CategoriesView (с подкатегориями)
│   ├── TransactionsView/          — список транзакций, детали, создание/редактирование
│   └── AnalyticsView/             — месячная аналитика с Charts
└── Utils/CurrentUserId.swift      — currentUserId() → UUID? из UserDefaults
```

## Data Models

| Модель      | Ключевые поля |
|-------------|--------------|
| `User`      | `id: UUID` (@unique), `login: String` (@unique) |
| `Account`   | `id: UUID` (@unique), `userId: UUID`, `name`, `balance: Decimal` (стартовый баланс) |
| `Category`  | `id: UUID` (@unique), `userId: UUID`, `name`, `type`, `parentId: UUID? = nil`, `isDefault: Bool = false` |
| `Transaction` | `userId`, `amount: Decimal`, `date`, `type`, `fromAccount?`, `toAccount?`, `fromCategory?`, `toCategory?`, `recurringGroupId: UUID?`, `recurringInterval?`, `recurringIntervalDays: Int?` |

**Важно:** баланс счёта = `account.balance` + все транзакции через `AccountService.collectAmountTransactions`. `account.balance` — только стартовый баланс, не текущий.

## Coding Standards

- **Сервисы** — `struct` с `let context: ModelContext`. Не `class`. Создаются inline: `AccountService(context: context)`
- **Computed property для сервиса** в View: `private var accountService: AccountService { AccountService(context: context) }` — это нормально
- **Текущий пользователь** — всегда через `currentUserId()` из `Utils/`. Никогда не передавать userId через init View
- **Именование:** View → `XxxView`, Sheet → `XxxSheet`, Service → `XxxService`, Model → просто `Xxx`
- **Дизайн:** использовать `AppTheme.Colors.*` и `.cardStyle()` для карточек. Не хардкодить цвета
- **Форматирование чисел:** `.number.precision(.fractionLength(0...2))` + `Text("₽")` рядом. Не интерполировать
- **Decimal:** для денежных сумм всегда `Decimal`, не `Double`. `Double` только для Charts (`NSDecimalNumber`)
- **Нет force unwrap** — только `guard let` / `if let`
- **Нет комментариев** к очевидному коду — только к нетривиальной логике

## SwiftData: Критические Правила

### Миграция схемы
При добавлении нового поля в `@Model`:
- Опциональные поля (`UUID?`) — мигрируют автоматически
- **Не-опциональные поля (`Bool`, `Int` и т.д.) ОБЯЗАТЕЛЬНО** с дефолтом в объявлении: `var isActive: Bool = false`, не `var isActive: Bool`
- Без дефолта в объявлении → краш при миграции → потеря данных

### Удаление объектов из SwiftData (anti-crash pattern)
Никогда не удалять SwiftData объект пока View, которое его отображает, ещё в иерархии. Паттерн:
```swift
// 1. Сохранить действие
pendingAction = { service.deleteTransaction(transaction) }
// 2. Убрать объект из отображения (закрыть sheet)
selectedTransaction = nil
// 3. Выполнить удаление ПОСЛЕ того как View исчезла
.onDisappear { pendingAction?(); pendingAction = nil }
```

### Редактирование через onSaved callback
`EditTransactionView` передаёт действие с БД наверх через `onSaved: (@escaping () -> Void) -> Void`. Родитель хранит его в `@State var pendingAction` и выполняет в `.onDisappear`. Никаких `Task.sleep` задержек.

## Build & Run

```bash
# Открыть проект
open BalancePlaning.xcodeproj

# Сборка через CLI
xcodebuild -project BalancePlaning.xcodeproj -scheme BalancePlaning -destination 'platform=iOS Simulator,name=iPhone 16' build

# Тесты (если появятся)
xcodebuild test -project BalancePlaning.xcodeproj -scheme BalancePlaning -destination 'platform=iOS Simulator,name=iPhone 16'
```

Нет тестов, нет скриптов генерации, нет лinters.

## What NEVER to Do

1. **Не использовать `Task.sleep` для задержки перед удалением** SwiftData объектов — использовать `.onDisappear` паттерн
2. **Не добавлять не-опциональное поле в `@Model` без `= defaultValue`** в объявлении — сломает миграцию
3. **Не делать сервисы `class`** — они `struct`, нет mutable state
4. **Не хранить SwiftUI Views как stored properties** в других View — создавать прямо в `body`
5. **Не использовать `@Query` в не-View типах** — только в SwiftUI View
6. **Не вычислять текущий баланс через `account.balance` напрямую** — только `AccountService.currentBalance(for:)` или `balance(for:at:)`
7. **Не добавлять `import SwiftUI` в Model/Service файлы** — там нужен только `import Foundation`

## Quick Reference

```swift
// Текущий пользователь
currentUserId() -> UUID?   // из UserDefaults

// Цвета
AppTheme.Colors.income      // #00C897 зелёный
AppTheme.Colors.expense     // #FF6B6B красный
AppTheme.Colors.transfer    // #7B8FFF фиолетовый
AppTheme.Colors.accent      // #4F46E5 индиго
AppTheme.Colors.pageBackground // #F0F2F8

// Типы транзакций
TransactionType.income      // fromCategory → toAccount
TransactionType.expense     // fromAccount → toCategory
TransactionType.transaction // fromAccount → toAccount (перевод)

// Повторяющиеся операции
recurringGroupId: UUID?     // nil = обычная, UUID = серия
recurringInterval: RecurringInterval?  // .daily/.weekly/.biweekly/.monthly/.everyNDays
recurringIntervalDays: Int? // только для .everyNDays
```
