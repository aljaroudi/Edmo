//
//  DataSchema.swift
//  Edmo
//
//  Created by Mohammed on 3/15/26.
//

import Foundation
import SwiftData

typealias DataSchema = DataSchemaV1
typealias Item = DataSchema.Item

enum DataSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Item.self,
        ]
    }

    @Model
    final class Item {
        var timestamp: Date

        init(timestamp: Date) {
            self.timestamp = timestamp
        }
    }
}
