//
//  TabBarVisibilityModel.swift
//  BalancePlaning
//

import Observation

/// Shared state for hiding the custom tab bar when a detail screen
/// (e.g. LoanDetailView) has its own full-width bottom action bar.
@Observable
final class TabBarVisibilityModel {
    var isHidden: Bool = false
}
