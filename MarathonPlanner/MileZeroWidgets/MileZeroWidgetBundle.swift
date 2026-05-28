import WidgetKit
import SwiftUI

@main
struct MileZeroWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodaySmallWidget()
        TodayMediumWidget()
        LockScreenWidget()
    }
}
