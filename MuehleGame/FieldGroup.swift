//
//  FieldGroup.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 07.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

public class FieldGroup {
    public let all: [Field]
    public let type: GroupType
    
    public var isMühle: Bool {
        return self.all.only(same: { return $0.state })
    }
    
    var empty: [Field] {
        return self.all.filter({ return $0.state == .empty })
    }
    
    let jumpSize: Int
    
    func numberOfFields(for color: Game.Color) -> Int {
        var num = 0
        for field in self.all {
            if field.state == .filled(color: color) {
                num += 1
            }
        }
        return num
    }
    
    var relatedGroups: [FieldGroup]
    
    init(fields: [Field], type: GroupType) {
        guard fields.count == 3 else {
            fatalError("\(fields)")
        }
        self.all = fields
        self.type = type
        self.relatedGroups = []
        
        switch type {
        case .row:
            let sorted = fields.sorted(by: { return $0.column < $1.column })
            self.jumpSize = (sorted.last!.column - sorted.first!.column) / 2
            if !self.all.only(same: { return $0.row }) {
                fatalError("Wrong fields \(self.all)")
            }
        case .column:
            let sorted = fields.sorted(by: { return $0.row < $1.row })
            self.jumpSize = (sorted.last!.row - sorted.first!.row) / 2
            if !self.all.only(same: { return $0.column }) {
                fatalError("Wrong fields \(self.all)")
            }
        }
        
        for field in fields {
            switch self.type {
            case .row:
                field.rowGroup = self
            case .column:
                field.columnGroup = self
            }
        }
    }
    
    func muhle() -> Game.Color? {
        guard let firstColor = self.all.first?.state.color else { return nil }
        for field in all {
            guard let c = field.state.color else { return nil }
            if firstColor != c {
                return nil
            }
        }
        return firstColor
    }
    func numStepsToMühle(for color: Game.Color) -> Int? {
        let allFieldsToFill = self.all.filter({ return $0.state != Field.State.filled(color: color) })
        var total = 0
        var exclude: Set<Field> = Set(all.filter({ return $0.state == .filled(color: color)}))
        for field in allFieldsToFill {
            if let result = field.closesedField(with: color, exclude: exclude) {
                exclude.insert(result.field)
                total += result.distance
            } else {
                return nil
            }
        }
        return total
    }
}

extension FieldGroup: Equatable {
    public static func ==(lhs: FieldGroup, rhs: FieldGroup) -> Bool {
        guard lhs.type == rhs.type else {
            return false
        }
        for field in lhs.all {
            guard rhs.all.contains(field) else {
                return false
            }
        }
        return true
    }
}

extension FieldGroup {
    public enum GroupType: Equatable {
        case row
        case column
        
        public static func ==(lhs: GroupType, rhs: GroupType) -> Bool {
            switch (lhs,rhs) {
            case (.row,.row),(.column,.column):
                return true
            default:
                return false
            }
        }
    }
}
