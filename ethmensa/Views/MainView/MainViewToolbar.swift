//
//  Copyright © 2026 Alexandre Reol
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>.
//

import SwiftUI

struct MainViewToolbar: ToolbarContent {

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            FilterMenuView()
        }
#if !os(watchOS) && !os(visionOS) && !APPCLIP && !targetEnvironment(macCatalyst)
        ToolbarItem(placement: .topBarTrailing) {
            Button("LEGI_CARD", systemImage: "person.text.rectangle") {
                NavigationManager.shared.sheet = .legiCard
            }
        }
#endif
#if !APPCLIP
        ToolbarItem(placement: .topBarTrailing) {
            Button("SETTINGS", systemImage: "gear") {
                NavigationManager.shared.sheet = .settings
            }
        }
#endif
    }
}

/// The menu to filter and sort the mensa list and to change its cell size.
/// Every active filter is also shown as a removable chip by `FilterView`.
private struct FilterMenuView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var settingsManager: SettingsManager

    private var cellTypes: [(name: String, type: MensaCellType)] {
        var result: [(String, MensaCellType)] = [
            (.init(localized: "MINIMAL_VIEW"), .minimal),
            (.init(localized: "STANDARD_VIEW"), .standard)
        ]
        if UIDevice.current.userInterfaceIdiom == .phone {
            result.append(
                (String(localized: "LARGE_VIEW"), .large)
            )
        }
        return result
    }

    /// Runs a change made in the menu once the menu has closed, animated.
    /// Changed right away, the list would update behind the closing menu and the animation would not be visible.
    private func afterMenuCloses(_ change: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation {
                change()
            }
        }
    }

    /// A binding whose new values are set once the menu has closed, see `afterMenuCloses(_:)`.
    private func afterMenuCloses<Value>(_ binding: Binding<Value>) -> Binding<Value> {
        Binding {
            binding.wrappedValue
        } set: { newValue in
            afterMenuCloses {
                binding.wrappedValue = newValue
            }
        }
    }

    /// A binding that applies or removes the given filter, e.g. for a toggle.
    /// Toggles, unlike a picker, also allow deselecting the selected campus again.
    private func isActive(_ filter: MensaFilter) -> Binding<Bool> {
        Binding {
            MensaFilter.active.contains(filter)
        } set: { isActive in
            if isActive {
                filter.apply()
            } else {
                filter.remove()
            }
        }
    }

    private var selectedWeekdayName: String {
        if let weekdayCode = navigationManager.selectedWeekdayCodeOverride {
            MensaFilter.weekday(weekdayCode).localizedString
        } else {
            .init(localized: "NO_WEEKDAY_ALLERGEN_FILTER")
        }
    }

    var body: some View {
        Menu {
            Toggle(isOn: afterMenuCloses(isActive(.openOnly))) {
                Label("OPEN_ONLY", systemImage: MensaFilter.openOnly.systemImageName)
            }
            Section("LOCATION") {
                ForEach(Campus.CampusType.allCases.filter { $0 != .all }, id: \.rawValue) { campusType in
                    Toggle(campusType.localizedString, isOn: afterMenuCloses(isActive(.campus(campusType))))
                }
            }
            // The weekday allergen filter only has an effect once allergens are set in the settings.
            if !settingsManager.allergens.isEmpty {
                Section {
                    Picker(selection: afterMenuCloses($navigationManager.selectedWeekdayCodeOverride)) {
                        Text("NO_WEEKDAY_ALLERGEN_FILTER").tag(Int?.none)
                        ForEach(Date.weekdaysStartingAtOne, id: \.index) { weekday in
                            Text(weekday.string).tag(Int?.some(weekday.index))
                        }
                    } label: {
                        Label(
                            "WEEKDAY",
                            systemImage: MensaFilter.weekday(navigationManager.selectedWeekdayCode).systemImageName
                        )
                        Text(selectedWeekdayName)
                    }
                    .pickerStyle(.menu)
                }
            }
            Section {
                Picker(selection: afterMenuCloses($settingsManager.sortBy)) {
                    ForEach(SortType.allCases, id: \.rawValue) { sortType in
                        Text(sortType.localizedString).tag(sortType)
                    }
                } label: {
                    Label("SORT_BY", systemImage: MensaFilter.sorting(settingsManager.sortBy).systemImageName)
                    Text(settingsManager.sortBy.localizedString)
                }
                .pickerStyle(.menu)
                Picker(selection: afterMenuCloses($settingsManager.mensaCellType)) {
                    ForEach(cellTypes, id: \.type) { viewType in
                        Text(viewType.name)
                            .tag(viewType.type)
                    }
                } label: {
                    Label("MENSA_CELL_SIZE", systemImage: "square.text.square")
                    Text(cellTypes.first { $0.type == settingsManager.mensaCellType }?.name ?? "")
                }
                .pickerStyle(.menu)
            }
            if MensaFilter.isAnyActive {
                Section {
                    Button("RESET_FILTERS", systemImage: "xmark.circle") {
                        afterMenuCloses {
                            MensaFilter.removeAll()
                        }
                    }
                }
            }
        } label: {
            Label(
                "FILTER",
                systemImage: MensaFilter.isAnyActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }
}

#Preview {
    AppView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(MensaDataManager.shared)
        .environmentObject(NetworkManager.shared)
        .environmentObject(SettingsManager.shared)
}
