//
//  Field.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 07.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

public class Field {
    public internal(set) var state: State
    
    public let id: Int
    
    public let row: Int
    public let column: Int
    
    weak var rowGroup: FieldGroup? = nil
    weak var columnGroup: FieldGroup? = nil
    
    init(id: Int, row: Int, column: Int) {
        self.state = .empty
        self.id = id
        self.row = row
        self.column = column
    }
    
    var relatedFields: [Field] {
        return (self.rowGroup?.all.filter({ return $0 != self }) ?? []) + (self.columnGroup?.all.filter({ return $0 != self }) ?? [])
    }
    var sepetatedByOneFields: [Field] {
        var all: [Field] = []
        if let group = self.rowGroup {
            for other in group.all {
                if abs(self.column - other.column) == group.jumpSize {
                    all.append(other)
                }
            }
        }
        if let group = self.columnGroup {
            for other in group.all {
                if abs(self.row - other.row) == group.jumpSize {
                    all.append(other)
                }
            }
        }
        return all
    }
    
    var partOfMühle: Bool {
        return (self.rowGroup?.isMühle ?? false) || (self.columnGroup?.isMühle ?? false)
    }
    
    func wouldCompleteMühle(for color: Game.Color) -> Bool {
        var all: [Field] = []
        if let row = self.rowGroup {
            all = row.all
            all.remove(self)
            if all.count == 2 && all.only(matching: { return $0.state == .filled(color: color) }) {
                return true
            }
        }
        if let column = self.columnGroup {
            all = column.all
            all.remove(self)
            if all.count == 2 && all.only(matching: { return $0.state == .filled(color: color) }) {
                return true
            }
        }
        return false
    }
    
    func wouldCompleteMühle(for color: Game.Color, filledFrom from: Field) -> Bool {
        var all: [Field] = []
        if let row = self.rowGroup {
            all = row.all
            all.remove(self)
            if !all.contains(from) && all.count == 2 && all.only(matching: { return $0.state == .filled(color: color) }) {
                return true
            }
        }
        if let column = self.columnGroup {
            all = column.all
            all.remove(self)
            if !all.contains(from) && all.count == 2 && all.only(matching: { return $0.state == .filled(color: color) }) {
                return true
            }
        }
        return false
    }
    
    func numPicesMissingForMühle(for color: Game.Color) -> (row: Int?, column: Int?)? {
        guard let row = self.rowGroup, let column = self.columnGroup else { return nil }
        let rowValue: Int? = row.numberOfFields(for: color.opposite) != 0 ? nil : 3 - row.numberOfFields(for: color)
        let columnValue: Int? = column.numberOfFields(for: color.opposite) != 0 ? nil : 3 - column.numberOfFields(for: color)
        if rowValue == nil && columnValue == nil {
            return nil
        }
        return (rowValue,columnValue)
    }
    
    func newMühleInSteps(for color: Game.Color) -> (row: Int?, column: Int?)? {
        guard let row = self.rowGroup, let column = self.columnGroup else { return nil }
        let rowSteps = row.numStepsToMühle(for: color)
        let columnSteps = column.numStepsToMühle(for: color)
        if rowSteps == nil && columnSteps == nil {
            return nil
        }
        return (rowSteps,columnSteps)
    }
    
    /*
    func mühleIfFilledInSteps(for color: Game.Color) -> Int? {
        var all: [Field] = []
        var canidates
        if let row = self.rowGroup {
            all = row.all
            all.remove(self)
            if all.count == 2 && all.only(matching: { return $0.state == .filled(color: color) }) {
                return self.closesedField(with: color, exclude: Set(all))
            }
        }
        if let column = self.columnGroup {
            all = column.all
            all.remove(self)
            if all.count == 2 && all.only(matching: { return $0.state == .filled(color: color) }) {
                return true
            }
        }
        return false
    }
    */
    func numberOfRelatedFields(with color: Game.Color) -> Int {
        let num = (self.rowGroup?.numberOfFields(for: color) ?? 0) + (self.columnGroup?.numberOfFields(for: color) ?? 0)
        switch self.state {
        case .empty:
            return num
        case let .filled(color: c):
            if color == c {
                return num - 2
            } else {
                return num
            }
        }
    }
    
    var ring: Int {
        switch (self.row,self.column) {
        case (0,_),(6,_),(_,0),(_,6):
            return 0
        case (1,_),(5,_),(_,1),(_,5):
            return 1
        case (2,_),(4,_),(_,2),(_,4):
            return 2
        default:
            return -1
        }
    }
    /**
     Returns the distance to the other field regardless of the state seperating the fields.
     */
    func distance(to other: Field) -> Int {
        guard self != other else {
            return 0
        }
        var set: Set<Field> = [self]
        var numSteps: Int = 0
        while !set.contains(other) && numSteps < 7 {
            set = Set(set.flatMap({ (field) -> [Field] in
                return field.sepetatedByOneFields.filter({ return !set.contains($0) })
            }))
            numSteps += 1
        }
        return numSteps
    }
    /**
     Returns to distance to the closed colored stone if rechable through an empty path
     */
    func distanceToClosesed(color: Game.Color) -> Int? {
        switch self.state {
        case .empty:
            var preSet: Set<Field> = [self]
            var arr: [Field] = [self]
            var numSteps: Int = 0
            while !arr.isEmpty && numSteps < 7 {
                numSteps += 1
                var next: [Field] = []
                for f in arr {
                    for r in f.sepetatedByOneFields where !preSet.contains(r) {
                        switch r.state {
                        case .empty:
                            next.append(r)
                        case .filled(color: color):
                            return numSteps
                        default:
                            preSet.insert(r)
                        }
                    }
                    preSet.insert(f)
                }
                arr = next
            }
            return nil
        case .filled(color: color):
            return 0
        default:
            return nil
        }
    }
    
    func closesedField(with color: Game.Color, exclude: Set<Field>) -> (distance: Int, field: Field)? {
        var previous: [Field] = [self]
        let filterClosure: (Field) -> Bool = { return !exclude.contains($0) && ($0.state == .empty || $0.state == .filled(color: color)) }
        var current: [Field] = self.sepetatedByOneFields.filter(filterClosure)
        var numSteps: Int = 1
        var found: Field?
        while found == nil && !current.isEmpty && numSteps < 7 {
            if let f = current.first(where: { return $0.state == .filled(color: color) }) {
                found = f
                break
            }
            current = current.flatMap({ return $0.sepetatedByOneFields.filter({ return !previous.contains($0) }) }).filter(filterClosure)
            previous = previous.flatMap({ return $0.sepetatedByOneFields })
            numSteps += 1
        }
        if let result = found {
            return (numSteps,result)
        } else {
            return nil
        }
    }
    func reachable(from others: [Field]) -> Int? {
        var minimum: Int?
        for field in others {
            let new = self.distance(to: field)
            if let old = minimum {
                minimum = min(old, new)
            } else {
                minimum = new
            }
        }
        return minimum
    }
    
    var short: String {
        switch self.state {
        case .empty:
            return "  "
        case .filled(color: .white):
            return "⚪️"
        case .filled(color: .black):
            return "⚫️"
        }
    }
}

extension Field: Hashable {
    public static func ==(lhs: Field, rhs: Field) -> Bool {
        return lhs.row == rhs.row && lhs.column == rhs.column
    }
    public var hashValue: Int {
        return row * 10 + column
    }
}

extension Field: CustomStringConvertible {
    public var description: String {
        switch self.state {
        case .empty:
            return "Field(row: \(self.row), column: \(self.column))"
        default:
            return "Field(state: \(self.short), row: \(self.row), column: \(self.column))"
        }
    }
}

extension Field {
    public enum State: Equatable {
        case empty
        case filled(color: Game.Color)
        
        public static func ==(lhs: Field.State, rhs: Field.State) -> Bool {
            switch (lhs,rhs) {
            case (.empty,.empty):
                return true
            case let (.filled(color: l),.filled(color: r)):
                return l == r
            default:
                return false
            }
        }
        
        var color: Game.Color? {
            switch self {
            case .filled(color: let c):
                return c
            case .empty:
                return nil
            }
        }
    }
}
