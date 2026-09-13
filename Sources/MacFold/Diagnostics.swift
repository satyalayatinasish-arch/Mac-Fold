import Foundation
import os

/// Read with:
///
///     log show --last 5m --predicate 'subsystem == "local.yatin.mac-fold"'
///
/// Notice level, not info: info level lives only in memory, and `log show`
/// reads the on-disk store.
enum Diagnostics {
    static let geometry = Logger(subsystem: "local.yatin.mac-fold", category: "geometry")
    static let lid = Logger(subsystem: "local.yatin.mac-fold", category: "lid")
}
