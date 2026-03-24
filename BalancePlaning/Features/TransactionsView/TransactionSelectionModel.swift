//
//  TransactionSelectionModel.swift
//  BalancePlaning
//

import Observation

/// Shared state between TransactionsView and ContentView for the batch-selection bar.
/// ContentView renders the bar above the tab bar; TransactionsView drives the state.
@Observable
final class TransactionSelectionModel {
    var selectedCount: Int = 0
    var countLabel: String = ""
    var onCancel: () -> Void = {}
    var onBatchDelete: () -> Void = {}

    var isSelecting: Bool { selectedCount > 0 }
}
