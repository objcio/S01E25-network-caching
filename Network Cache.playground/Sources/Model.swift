public struct Episode {
    public var id: String
    public var title: String
}

extension Episode {
    public init?(json: JSONDictionary) {
        guard let id = json["id"] as? String,
            let title = json["title"] as? String
            else { return nil }
        self.id = id
        self.title = title
    }
}

