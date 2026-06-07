/// One physical display and the ordered Spaces that belong to it.
public struct DisplaySpaces: Equatable {
    public let uuid: String
    public let orderedSpaceIDs: [Int]
    public let currentSpaceID: Int?

    public init(uuid: String, orderedSpaceIDs: [Int], currentSpaceID: Int?) {
        self.uuid = uuid
        self.orderedSpaceIDs = orderedSpaceIDs
        self.currentSpaceID = currentSpaceID
    }
}

private func spaceID(_ dict: [String: Any]) -> Int? {
    (dict["ManagedSpaceID"] as? Int) ?? (dict["id64"] as? Int)
}

/// Parse the raw array produced by `CGSCopyManagedDisplaySpaces` into typed models.
public func parseDisplaySpaces(_ raw: [[String: Any]]) -> [DisplaySpaces] {
    raw.compactMap { entry in
        guard let uuid = entry["Display Identifier"] as? String else { return nil }
        let spaces = (entry["Spaces"] as? [[String: Any]]) ?? []
        let ids = spaces.compactMap(spaceID)
        let current = (entry["Current Space"] as? [String: Any]).flatMap(spaceID)
        return DisplaySpaces(uuid: uuid, orderedSpaceIDs: ids, currentSpaceID: current)
    }
}
