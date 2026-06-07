import Foundation

typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: CGSConnectionID) -> CFArray

/// Fetch the raw per-display spaces description from the WindowServer.
/// Returns an empty array if the private call yields an unexpected shape.
func rawManagedDisplaySpaces() -> [[String: Any]] {
    let connection = CGSMainConnectionID()
    let result = CGSCopyManagedDisplaySpaces(connection)
    return (result as? [[String: Any]]) ?? []
}
