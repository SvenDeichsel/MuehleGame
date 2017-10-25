//
//  Game.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 07.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

open class Game {
    let fields: [Field]
    
    public var fieldStates: [Field.State] {
        return self.fields.map({ return $0.state })
    }
    
    public func fieldStates(after move: Game.Move, with color: Game.Color) -> [Field.State] {
        switch move {
        case let .move(from: from, to: to):
            var states = self.fieldStates
            states[from.id] = .empty
            states[to.id] = from.state
            return states
        case let .remove(field):
            var states = self.fieldStates
            states[field.id] = .empty
            return states
        case let .place(in: field) :
            var states = self.fieldStates
            states[field.id] = .filled(color: color)
            return states
        }
    }
    
    public let whitePlayer: Player
    public let blackPlayer: Player
    
    var history: [[Field.State]] = []
    
    private func player(for color: Game.Color) -> Player {
        switch color {
        case .white:
            return self.whitePlayer
        case .black:
            return self.blackPlayer
        }
    }
    
    var leftPerlsToPlace: [Game.Color: Int] = [.white: 9, .black: 9]
    
    var emptyFields: [Field] {
        return self.fields.filter({ return $0.state == .empty })
    }
    func fields(for color: Game.Color) -> [Field] {
        return self.fields.filter({ return $0.state == .filled(color: color)})
    }
    
    func fields(nextTo p: Field) -> [Field] {
        var all: [Field] = []
        if let rowFields = p.rowGroup?.all.sorted(by: { return $0.column < $1.column }) {
            let dif = (rowFields.last!.column - rowFields.first!.column) / 2
            for field in rowFields {
                guard abs(field.column - p.column) == dif else { continue }
                all.append(field)
            }
        } else {
            self.log("No row")
        }
        if let columnFields = p.columnGroup?.all.sorted(by: { return $0.row < $1.row }) {
            let dif = (columnFields.last!.row - columnFields.first!.row) / 2
            for field in columnFields {
                guard abs(field.row - p.row) == dif else { continue }
                all.append(field)
            }
        } else {
            self.log("No column")
        }
        return all
    }
    
    func fieldsInRow(_ row: Int) -> [Field] {
        return self.fields.filter({ return $0.row == row })
    }
    func fieldsInColumn(_ column: Int) -> [Field] {
        return self.fields.filter({ return $0.column == column })
    }
    
    public let groups: [FieldGroup]
    
    public convenience init<White: InitializablePlayer, Black: InitializablePlayer>(whiteType: White.Type, blackType: Black.Type) {
        self.init(white: White(color: .white), black: Black(color: .black))
    }
    
    public init(white: Player, black: Player) {
        self.whitePlayer = white
        self.blackPlayer = black
        
        var all: [Field] = []
        var i = 0
        for row in 0...6 {
            switch row {
            case 0,6:
                for column in [0,3,6] {
                    all.append(Field(id: i, row: row, column: column))
                }
            case 1,5:
                for column in [1,3,5] {
                    all.append(Field(id: i, row: row, column: column))
                }
            case 2,4:
                for column in [2,3,4] {
                    all.append(Field(id: i, row: row, column: column))
                }
            case 3:
                for column in [0,1,2,4,5,6] {
                    all.append(Field(id: i, row: row, column: column))
                }
            default:
                break
            }
            i += 1
        }
        self.fields = all
        var groups: [FieldGroup] = []
        for id in 0...6 {
            let rowFields = all.filter({ return $0.row == id })
            if rowFields.count == 3 {
                groups.append(FieldGroup(fields: rowFields, type: .row))
            } else {
                var temp = rowFields.filter({ return $0.column < 3 })
                groups.append(FieldGroup(fields: temp, type: .row))
                temp = rowFields.filter({ return $0.column > 3 })
                groups.append(FieldGroup(fields: temp, type: .row))
            }
            let columnFields = all.filter({ return $0.column == id })
            if columnFields.count == 3 {
                groups.append(FieldGroup(fields: columnFields, type: .column))
            } else {
                var temp = columnFields.filter({ return $0.row < 3 })
                groups.append(FieldGroup(fields: temp, type: .column))
                temp = columnFields.filter({ return $0.row > 3 })
                groups.append(FieldGroup(fields: temp, type: .column))
            }
        }
        self.groups = groups
        
        for field in all {
            if let row = field.rowGroup, let column = field.columnGroup {
                row.relatedGroups.append(column)
                column.relatedGroups.append(row)
            } else {
                self.log("Missing row or column \(field)")
            }
        }
    }
    
    public private(set) var log: String = ""
    open func log(_ str: String) {
        print(str)
        log += str + "\n"
    }
    
    @discardableResult
    public func play() -> Game.Color? {
        var count = 1
        var phase: Phase = Phase.placing(as: .white)
        //let semaphore = DispatchSemaphore.init(value: 0)
        while let color = phase.playingColor() {
            self.log("Round \(count)\nPlayer: \(color)")
            self.log(self.description)
            
            //_ = semaphore.wait(timeout: .now() + .seconds(3))
            
            self.history.append(self.fields.map({ $0.state }))
            
            guard let next = self.perform(phase: phase, for: self.player(for: color)) else {
                return nil
            }
            
            phase = next
            count += 1
            
            if count > 250 {
                print("Draw because game didn't end.")
                print(self.description)
                phase = .draw
                break
            }
            /*
            if count > 100 {
                let last = history.last!
                var lastInt = -1
                var currentCount = 0
                for h in history.last(n: 10).reversed() {
                    if last == h {
                        if lastInt == currentCount {
                            break
                        } else {
                            lastInt = currentCount
                        }
                        currentCount = 0
                    } else {
                        currentCount += 1
                    }
                }
                if lastInt < 10 && lastInt > 1 {
                    let currentState = self.fields.map({ return $0.state })
                    print("Repeating moves detected -> Game is a draw")
                    var c = 1
                    for h in history.last(n: lastInt * 3) {
                        print("State \(c)")
                        for (i,state) in h.enumerated() {
                            self.fields[i].state = state
                        }
                        print(self.description)
                        c += 1
                    }
                    for (i,state) in currentState.enumerated() {
                        self.fields[i].state = state
                    }
                    print("Current State")
                    print(self.description)
                    
                    phase = .draw
                    break
                }
            }
            */
        }
        self.log(self.description)
        
        switch phase {
        case .draw:
            self.log("Draw")
            self.whitePlayer.draw(game: self)
            self.blackPlayer.draw(game: self)
            return nil
        case .winner(let c):
            self.log("Winner \(c)")
            self.player(for: c).won(game: self)
            self.player(for: c.opposite).lost(game: self)
            return c
        default:
            self.log("End")
            return nil
        }
    }
    func perform(phase: Phase, for player: Player) -> Phase? {
        let possible = self.possibleMoves(for: phase)
        guard possible.containsMoves() else {
            if let c = phase.playingColor() {
                return Phase.winner(c.opposite)
            } else {
                return nil
            }
        }
        guard let move = player.chooseMove(from: possible, in: self) else {
            self.log("Game forfitted by \(player)")
            return nil
        }
        let result = self.perform(move: move, currentPhase: phase)
        guard result.success else {
            self.log("No move performed")
            return nil
        }
        for other in result.nextPhase {
            guard (self.perform(phase: other, for: player) != nil) else {
                return nil
            }
        }
        return self.nextPhase(for: phase)
    }
    
    public func resetBoard() {
        self.log = ""
        for field in self.fields {
            field.state = .empty
        }
        self.leftPerlsToPlace = [.white: 9, .black: 9]
        self.history = []
    }
}

extension Game {
    public enum Color: Int, Codable, CustomStringConvertible {
        case white = 0
        case black = 1
        
        var opposite: Color {
            switch self {
            case .white:
                return .black
            case .black:
                return .white
            }
        }
        
        public var description: String {
            switch self {
            case .white:
                return "White"
            case .black:
                return "Black"
            }
        }
        
        func floatValue(with own: Color) -> Float {
            if self == own {
                return 1.0
            } else {
                return -1.0
            }
        }
        
    }
}

// Gameplay {
extension Game {
    public enum Phase {
        case placing(as: Game.Color)
        case moving(as: Game.Color)
        case remove(as: Game.Color)
        case jumping(for: Game.Color)
        
        case winner(Color)
        case draw
        
        func playingColor() -> Game.Color? {
            switch self {
            case .placing(as: let c), .moving(as: let c), .remove(as: let c), .jumping(for: let c):
                return c
            case .winner(_),.draw:
                return nil
            }
        }
    }
    
    public enum PossibleMove {
        case place(inEither: [Field])
        case move([(from: Field, to: [Field])])
        case remove(either: [Field])
        
        case noMove
        
        public func convertToMoves() -> [Move] {
            switch self {
            case .place(inEither: let all):
                return all.map({ (field) -> Move in
                    return Move.place(in: field)
                })
            case .move(let all):
                return all.flatMap({ (all) -> [Game.Move] in
                    return all.to.map({ (field) -> Game.Move in
                        return Move.move(from: all.from, to: field)
                    })
                })
            case .remove(either: let all):
                return all.map({ (field) -> Move in
                    return Move.remove(field)
                })
            case .noMove:
                return []
            }
        }
        public func containsMoves() -> Bool {
            switch self {
            case .place(inEither: let all):
                return !all.isEmpty
            case .move(let all):
                return all.first(where: { return !$0.to.isEmpty }) != nil
            case .remove(either: let all):
                return !all.isEmpty
            case .noMove:
                return false
            }
        }
    }
    
    func possibleMoves(for phase: Phase) -> PossibleMove {
        switch phase {
        case .placing(as: _):
            return PossibleMove.place(inEither: self.emptyFields)
        case .moving(as: let c):
            var all: [(from: Field, to: [Field])] = []
            for p in self.fields(for: c) {
                let next = self.fields(nextTo: p).filter({ return $0.state == .empty })
                guard !next.isEmpty else { continue }
                all.append((from: p, to: next))
            }
            guard !all.isEmpty else {
                return PossibleMove.noMove
            }
            return PossibleMove.move(all)
        case .jumping(for: let c):
            var all: [(from: Field, to: [Field])] = []
            for p in self.fields(for: c) {
                all.append((from: p, to: self.emptyFields))
            }
            guard !all.isEmpty else {
                return PossibleMove.noMove
            }
            return PossibleMove.move(all)
        case .remove(as: let c):
            let all = self.fields(for: c.opposite)
            let filteredForMühle = all.filter({ (field) -> Bool in
                return !field.partOfMühle
            })
            guard !filteredForMühle.isEmpty else {
                return PossibleMove.remove(either: all)
            }
            return PossibleMove.remove(either: filteredForMühle)
        case .draw, .winner(_):
            return .noMove
        }
    }
}

extension Game {
    public enum Move {
        case place(in: Field)
        case move(from: Field, to: Field)
        case remove(Field)
    }
    
    public func perform(move: Move, currentPhase phase: Game.Phase) -> (success: Bool, nextPhase: [Game.Phase]) {
        switch move {
        case let .place(in: field):
            guard field.state == .empty else {
                return (false,[])
            }
            switch phase {
            case .placing(as: let c):
                guard let left = self.leftPerlsToPlace[c], left > 0 else {
                    return (false,[])
                }
                self.leftPerlsToPlace[c] = left - 1
                field.state = .filled(color: c)
                
                self.log("Placed \(c.description) at \(field.description)")
                
                var next: [Phase] = []
                if let m = field.rowGroup?.muhle(), m == c {
                    next.append(Phase.remove(as: c))
                }
                if let m = field.columnGroup?.muhle(), m == c {
                    next.append(Phase.remove(as: c))
                }
                
                return (true,next)
            default:
                return (false,[])
            }
        case let .remove(field):
            guard field.state != .empty else {
                return (false,[])
            }
            switch phase {
            case .remove(as: let c):
                guard field.state != .filled(color: c) else {
                    return (false,[])
                }
                if field.partOfMühle {
                    let hasOtherFields = self.fields(for: c.opposite).contains(where: { return !$0.partOfMühle })
                    if hasOtherFields {
                        return (false,[])
                    }
                }
                let fieldStr = field.short
                field.state = .empty
                self.log("Removed \(fieldStr) at \(field)")
                return (true,[])
            default:
                return (false,[])
            }
        case let .move(from: from, to: to):
            switch phase {
            case .jumping(for: let c):
                guard from.state == .filled(color: c) && to.state == .empty else {
                    return (false,[])
                }
                from.state = .empty
                to.state = .filled(color: c)
                
                self.log("Jumped \(to.short) from \(from) to \(to)")
                
                var next: [Phase] = []
                if let m = to.rowGroup?.muhle(), m == c {
                    next.append(Phase.remove(as: c))
                }
                if let m = to.columnGroup?.muhle(), m == c {
                    next.append(Phase.remove(as: c))
                }
                
                return (true,next)
            case .moving(as: let c):
                let possibleFields = self.fields(nextTo: from)
                guard possibleFields.contains(to) else {
                    return (false,[])
                }
                from.state = .empty
                to.state = .filled(color: c)
                
                self.log("Moved \(to.short) from \(from) to \(to)")
                
                var next: [Phase] = []
                if let m = to.rowGroup?.muhle(), m == c {
                    next.append(Phase.remove(as: c))
                }
                if let m = to.columnGroup?.muhle(), m == c {
                    next.append(Phase.remove(as: c))
                }
                
                return (true,next)
            default:
                return (false,[])
            }
        }
    }
    
    public func nextPhase(for phase: Game.Phase) -> Game.Phase {
        switch phase {
        case .placing(as: let c):
            let other: Color = c.opposite
            if (self.leftPerlsToPlace[other] ?? 0) > 0 {
                return .placing(as: other)
            } else {
                return self.nextPhaseForMoving(with: other)
            }
        case let .moving(as: color):
            return self.nextPhaseForMoving(with: color.opposite)
        case let .jumping(for: color):
            return self.nextPhaseForMoving(with: color.opposite)
        case let .remove(as: color):
            return self.nextPhaseForMoving(with: color.opposite)
        case .draw,.winner(_):
            return phase
        }
    }
    
    func nextPhaseForMoving(with color: Color) -> Phase {
        let count = self.fields(for: color).count
        if count < 3 {
            let other = color.opposite
            if self.fields(for: other).count >= 3 {
                return .winner(other)
            } else {
                return .draw
            }
        } else if count == 3 {
            return .jumping(for: color)
        } else {
            return .moving(as: color)
        }
    }
    func canJump(color: Game.Color) -> Bool {
        return self.fields(for: color).count <= 3
    }
}

public class GameNoPrint: Game {
    public override func log(_ str: String) {
        
    }
}

// Output

extension Int {
    var whitespaces: String {
        return String(repeating: " ", count: self)
    }
}

extension Game: CustomStringConvertible {
    func description(with c: (Field) -> String) -> String {
        func seperatorString(spaces: Int, Fields: Int) -> String {
            return String.init(repeating: "-", count: spaces*2+Fields*2)
        }
        var str: String = ""
        for row in 0...6 {
            // Row string
            switch row {
            case 0,6:
                str += self.fieldsInRow(row).map({ return c($0) }).joined(separator: seperatorString(spaces: 3, Fields: 2))
            case 1,5:
                str += "|" + 3.whitespaces
                str += self.fieldsInRow(row).map({ return c($0) }).joined(separator: seperatorString(spaces: 2, Fields: 1))
                str.append(3.whitespaces + "|")
            case 2,4:
                str += "|" + 3.whitespaces + "|" + 3.whitespaces
                str += self.fieldsInRow(row).map({ return c($0) }).joined(separator: seperatorString(spaces: 1, Fields: 0))
                str.append(3.whitespaces + "|" + 3.whitespaces + "|")
            case 3:
                let Fields = fieldsInRow(row).sorted(by: { return $0.column < $1.column })
                str += Fields[..<3].map({ return c($0) }).joined(separator: "--")
                str += 6.whitespaces
                str += Fields[3...].map({ return c($0) }).joined(separator: "--")
            default:
                break
            }
            // Seperator string
            switch row {
            case 0,5:
                str += "\n"
                str += "|" + 11.whitespaces + "||" + 11.whitespaces + "|"
                str += "\n"
            case 1,4:
                str.append("\n")
                str.append("|" + 3.whitespaces)
                str += "|" + 7.whitespaces + "||" + 7.whitespaces + "|"
                str.append(3.whitespaces + "|")
                str += "\n"
            case 2,3:
                str.append("\n")
                let sepStr = [String](repeating: "|", count: 3).joined(separator: 3.whitespaces)
                str += sepStr
                str += 8.whitespaces
                str += sepStr
                str.append("\n")
            default:
                break
            }
        }
        return str
    }
    
    func description(with path: KeyPath<Field,String>) -> String {
        return description(with: {(f: Field) -> String in return f[keyPath: path] })
    }
    
    public var description: String {
        return description(with: \Field.short)
        /*
        func seperatorString(spaces: Int, Fields: Int) -> String {
            return String.init(repeating: "-", count: spaces*2+Fields*2)
        }
        var str: String = ""
        for row in 0...6 {
            // Row string
            switch row {
            case 0,6:
                str += self.fieldsInRow(row).map({ return $0.short }).joined(separator: seperatorString(spaces: 3, Fields: 2))
            case 1,5:
                str += "|" + 3.whitespaces
                str += self.fieldsInRow(row).map({ return $0.short }).joined(separator: seperatorString(spaces: 2, Fields: 1))
                str.append(3.whitespaces + "|")
            case 2,4:
                str += "|" + 3.whitespaces + "|" + 3.whitespaces
                str += self.fieldsInRow(row).map({ return $0.short }).joined(separator: seperatorString(spaces: 1, Fields: 0))
                str.append(3.whitespaces + "|" + 3.whitespaces + "|")
            case 3:
                let Fields = fieldsInRow(row).sorted(by: { return $0.column < $1.column })
                str += Fields[..<3].map({ return $0.short }).joined(separator: "--")
                str += 6.whitespaces
                str += Fields[3...].map({ return $0.short }).joined(separator: "--")
            default:
                break
            }
            // Seperator string
            switch row {
            case 0,5:
                str += "\n"
                str += "|" + 11.whitespaces + "||" + 11.whitespaces + "|"
                str += "\n"
            case 1,4:
                str.append("\n")
                str.append("|" + 3.whitespaces)
                str += "|" + 7.whitespaces + "||" + 7.whitespaces + "|"
                str.append(3.whitespaces + "|")
                str += "\n"
            case 2,3:
                str.append("\n")
                let sepStr = [String](repeating: "|", count: 3).joined(separator: 3.whitespaces)
                str += sepStr
                str += 8.whitespaces
                str += sepStr
                str.append("\n")
            default:
                break
            }
        }
        return str
        */
    }
}
