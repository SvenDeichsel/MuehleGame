//
//  Game.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 07.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

/**
 Das Game Objekt ist ein Mühle Spiel.
 
 Alle Funktionen von einem Mühlespiel müssen auf dem selben Thread aufgerufen werden.
 */
open class Game {
    
    //MARK: - Felder
    /// Die Mühle Felder, von oben nach unten und links nach rechts sortiert.
    let fields: [Field]
    
    /// Die Zustände der Mühlefelder, von oben nach unten und links nach rechts sortiert.
    public var fieldStates: [Field.State] {
        return self.fields.map({ return $0.state })
    }
    
    /// Die Zustände der Mühlefelder, nachdem ein bestimmter Zug durchgeführt wurde.
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
    
    var emptyFields: [MuehleField] {
        return self.fields.filter({ return $0.state == .empty }).map({ return MuehleField(field: $0) })
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
            if self.loggingEnabled {
                self.log("No row")
            }
        }
        if let columnFields = p.columnGroup?.all.sorted(by: { return $0.row < $1.row }) {
            let dif = (columnFields.last!.row - columnFields.first!.row) / 2
            for field in columnFields {
                guard abs(field.row - p.row) == dif else { continue }
                all.append(field)
            }
        } else {
            if self.loggingEnabled {
                self.log("No column")
            }
        }
        return all
    }
    
    func fieldsInRow(_ row: Int) -> [Field] {
        return self.fields.filter({ return $0.row == row })
    }
    func fieldsInColumn(_ column: Int) -> [Field] {
        return self.fields.filter({ return $0.column == column })
    }
    
    // MARK: - Delegate
    
    weak var delegate: GameDelegate?
    
    //MARK: - Spieler
    /// Der Spieler mit den weißen Steinen
    public private(set) var whitePlayer: Player
    
    /// Der Spieler mit den weißen Steinen
    public private(set) var blackPlayer: Player
    
    /// Gibt den Spieler für die Farbe zurück
    private func player(for color: Game.Color) -> Player {
        switch color {
        case .white:
            return self.whitePlayer
        case .black:
            return self.blackPlayer
        }
    }
    /// Ändert den Spieler für die gegebene Farbe
    func changePlayer(for color: Game.Color, to: Player) {
        switch color {
        case .white:
            self.whitePlayer = to
        case .black:
            self.blackPlayer = to
        }
    }
    
    
    //MARK: - History
    /// Eine Variable, die bestimmt, ob vergangede Zustände gespeichert werden
    var keepHistory: Bool = true
    /// All vergangenden Züstande
    var history: [[Field.State]] = []
    
    //MARK: - Gruppen
    /// Alle Feldgruppen dieses Spiels
    public let groups: [FieldGroup]
    
    
    // MARK: - Current game play
    public var currentPhase: Game.Phase?
    
    //MARK: - Initializers
    
    /// Erstellt ein Spiel mit den gegebenen Player-Typen
    ///
    /// - Parameters:
    ///   - whiteType: Bestimmt den Type vom weißen Spieler
    ///   - blackType: Bestimmt den Type vom schwarzen Spieler
    public convenience init<White: InitializablePlayer, Black: InitializablePlayer>(whiteType: White.Type, blackType: Black.Type) {
        self.init(white: White(color: .white), black: Black(color: .black))
    }
    
    /// Erstellt ein Spiel mit den gegebenen Spielern
    ///
    /// - Parameters:
    ///   - white: Der weiße Spieler
    ///   - black: Der schwarze Spieler
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
                    i += 1
                }
            case 1,5:
                for column in [1,3,5] {
                    all.append(Field(id: i, row: row, column: column))
                    i += 1
                }
            case 2,4:
                for column in [2,3,4] {
                    all.append(Field(id: i, row: row, column: column))
                    i += 1
                }
            case 3:
                for column in [0,1,2,4,5,6] {
                    all.append(Field(id: i, row: row, column: column))
                    i += 1
                }
            default:
                break
            }
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
                if self.loggingEnabled {
                    self.log("Missing row or column \(field)")
                }
            }
        }
    }
    
    deinit {
        for group in self.groups {
            group.relatedGroups = []
        }
    }
    
    //MARK: - Log
    /// Bestimmt, ob ein Log erstellt wird
    open var loggingEnabled: Bool = true
    /// Der Speicher für den Log
    public private(set) var log: String = ""
    /// Die Funktion, die aufgerufen wird um eine String zum Log hinzuzufügen.
    open func log(_ str: String) {
        print(str)
        log += str + "\n"
    }
    
    //MARK: Spielen
    /// Startet ein Mühlespiel
    ///
    /// - WARNING: Muss auf einem Hintergrundthread aufgerufen werden, da diese Funktion erst zurückkehrt, wenn das Spiel beendet wurde.
    /// - Returns: Den Gewinner, falls es einen gab.
    @discardableResult
    public func play(start: Game.Phase? = nil) -> Game.Color? {
        var count = 1
        var phase: Phase = start ?? Phase.placing(as: .white, leftStones: (9,9))
        self.currentPhase = phase
        
        var lastMühleClosedAt: Int = 1
        var mühlenWhite = self.numMühlen(for: .white)
        var mühlenBlack = self.numMühlen(for: .black)
        
        while let color = phase.playingColor() {
            if self.loggingEnabled {
                self.log("Round \(count)\nPlayer: \(color)")
                self.log(self.description)
            }
            if self.keepHistory {
                self.history.append(self.fields.map({ $0.state }))
            }
            guard let next = self.perform(phase: phase, for: self.player(for: color)) else {
                phase = .winner(color.opposite)
                break
            }
            
            phase = next
            self.currentPhase = next
            count += 1
            
            // Überprüfe, ob eine Mühle geschlossen wurde
            let newWhite = self.numMühlen(for: .white)
            if newWhite > mühlenWhite {
                lastMühleClosedAt = count
            }
            mühlenWhite = newWhite
            
            let newBlack = self.numMühlen(for: .black)
            if newBlack > mühlenBlack {
                lastMühleClosedAt = count
            }
            mühlenBlack = newBlack
            
            // Beende das Spiel, wenn seit mehr als 50 Zügen keine Mühle geschlossen wurde
            if count - lastMühleClosedAt > 50 {
                print("Draw because no Mühle closed in over 75 moves")
                print(self.description)
                phase = .draw
                break
            }
            /*
            if count > 300 {
                print("Draw because game didn't end.")
                print(self.description)
                phase = .draw
                break
            }
            */
        }
        
        self.currentPhase = nil
        
        if self.loggingEnabled {
            self.log(self.description)
        }
        
        // Spiel ist beendet
        switch phase {
        case .draw:
            if self.loggingEnabled {
                self.log("Draw")
            }
            self.whitePlayer.draw(game: self)
            self.blackPlayer.draw(game: self)
            return nil
        case .winner(let c):
            if self.loggingEnabled {
                self.log("Winner \(c)")
            }
            self.player(for: c).won(game: self)
            self.player(for: c.opposite).lost(game: self)
            return c
        default:
            if self.loggingEnabled {
                self.log("End")
            }
            return nil
        }
    }
    
    func numMühlen(for color: Color) -> Int {
        var num = 0
        for group in groups {
            if let c = group.muhle(), c == color {
                num += 1
            }
        }
        return num
    }
    
    /// Setzt das Spielfeld zurück, sodass ein weiteres Spiel gespielt werden kann.
    public func resetBoard() {
        if self.loggingEnabled {
            self.log = ""
        }
        for field in self.fields {
            guard field.state != .empty else { continue }
            field.state = .empty
            self.delegate?.needsRefresh(at: field)
        }
        self.history = []
    }
    
    /// Führt eine bestimmten Spielzug für den übergebenen Spieler aus und gibt die nächste Spielphase zurück
    ///
    /// - Parameters:
    ///   - phase: Die jetzige Spielphase
    ///   - player: Der jetzige Spiele
    /// - Returns: Die nächste Spielphase
    func perform(phase: Phase, for player: Player) -> Phase? {
        let possible = self.possibleMoves(for: phase)
        guard possible.containsMoves() else {
            if let c = phase.playingColor() {
                return Phase.winner(c.opposite)
            } else {
                return nil
            }
        }
        
        guard let move = player.chooseMove(from: possible, phase: phase, in: self) else {
            if self.loggingEnabled {
                self.log("Game forfitted by \(player)")
            }
            return nil
        }
        let result = self.perform(move: move, currentPhase: phase)
        guard result.success else {
            if self.loggingEnabled {
                self.log("No move performed")
            }
            return nil
        }
        self.informDelegate(of: move, by: player)
        if let next = result.nextPhase {
            guard (self.perform(phase: next, for: player) != nil) else {
                return nil
            }
        }
        return self.nextPhase(for: phase)
    }
    
    
    /// Führt den gegebenen Zug aus
    ///
    /// - Parameters:
    ///   - move: Der auszuführende Zug
    ///   - phase: Die zurzeitige Spielphase
    /// - Returns: success: True, wenn der Zug erfolgreich ausgeführt wurde, nextPhase: eine resultierende Spielphase, falls eine Mühle geschlossen wurde
    public func perform(move: Move, currentPhase phase: Game.Phase) -> (success: Bool, nextPhase: Game.Phase?) {
        switch move {
        case let .place(in: f):
            guard f.state == .empty else {
                return (false,nil)
            }
            switch phase {
            case let .placing(as: c, leftStones: stones):
                switch c {
                case .white:
                    guard stones.white > 0 else {
                        return (false,nil)
                    }
                case .black:
                    guard stones.black > 0 else {
                        return (false,nil)
                    }
                }
                let field = self.field(for: f)
                field.state = .filled(color: c)
                
                if self.loggingEnabled {
                    self.log("Placed \(c.description) at \(field.description)")
                }
                
                if let m = field.rowGroup?.muhle(), m == c {
                    return (true, Phase.remove(as: c))
                }
                if let m = field.columnGroup?.muhle(), m == c {
                    return (true, Phase.remove(as: c))
                }
                
                return (true,nil)
            default:
                return (false,nil)
            }
        case let .remove(f):
            guard f.state != .empty else {
                return (false,nil)
            }
            switch phase {
            case .remove(as: let c):
                guard f.state != .filled(color: c) else {
                    return (false,nil)
                }
                let field = self.field(for: f)
                if field.partOfMühle {
                    let hasOtherFields = self.fields(for: c.opposite).contains(where: { return !$0.partOfMühle })
                    if hasOtherFields {
                        return (false,nil)
                    }
                }
                let fieldStr = field.short
                field.state = .empty
                if self.loggingEnabled {
                    self.log("Removed \(fieldStr) at \(field)")
                }
                return (true,nil)
            default:
                return (false,nil)
            }
        case let .move(from: fromF, to: toF):
            switch phase {
            case .jumping(for: let c):
                let from = self.field(for: fromF)
                let to = self.field(for: toF)
                guard from.state == .filled(color: c) && to.state == .empty else {
                    return (false,nil)
                }
                from.state = .empty
                to.state = .filled(color: c)
                if self.loggingEnabled {
                    self.log("Jumped \(to.short) from \(from) to \(to)")
                }
                // Nur eine Mühle kann be jedem Zug geschlossen werden
                if let m = to.rowGroup?.muhle(), m == c {
                    return (true, Phase.remove(as: c))
                }
                if let m = to.columnGroup?.muhle(), m == c {
                    return (true, Phase.remove(as: c))
                }
                
                return (true,nil)
            case .moving(as: let c):
                let from = self.field(for: fromF)
                let to = self.field(for: toF)
                let possibleFields = self.fields(nextTo: from)
                guard possibleFields.contains(to) else {
                    return (false,nil)
                }
                from.state = .empty
                to.state = .filled(color: c)
                if self.loggingEnabled {
                    self.log("Moved \(to.short) from \(from) to \(to)")
                }
                if let m = to.rowGroup?.muhle(), m == c {
                    return (true, Phase.remove(as: c))
                }
                if let m = to.columnGroup?.muhle(), m == c {
                    return (true, Phase.remove(as: c))
                }
                
                return (true,nil)
            default:
                return (false,nil)
            }
        }
    }
    
    /// Bestimmt die nächste Spielphase nach der jetzigen
    public func nextPhase(for phase: Game.Phase) -> Game.Phase {
        switch phase {
        case let .placing(as: c, leftStones: stones):
            let other: Color = c.opposite
            // Subtract one stone for the current color since it was placed
            switch other {
            case .white:
                if stones.white > 0 {
                    return Game.Phase.placing(as: other, leftStones: (white: stones.white, black: stones.black - 1))
                }
            case .black:
                if stones.black > 0 {
                    return Game.Phase.placing(as: other, leftStones: (white: stones.white - 1, black: stones.black))
                }
            }
            return self.nextPhaseForMoving(with: other)
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
    
    /// Gibt die nächste Spielphase zurück, wenn die übergebene Farbe als nächstes einen Stein bewegen darf
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
    /// Gibt zurück, ob der Spieler mit der gegebenen Farbe springen darf
    func canJump(color: Game.Color) -> Bool {
        return self.fields(for: color).count <= 3
    }
}

extension Game {
    
    /// Informiert das Delegate-Object, über einen Zug
    ///
    /// - Parameters:
    ///   - move: Der Zug
    ///   - player: Der Spieler, welcher den Zug durchgeführt hat
    func informDelegate(of move: Move, by player: Player) {
        guard let d = self.delegate else { return }
        switch move {
        case let .place(in: f):
            if player is MuehleScene {
                d.needsRefresh(at: self.field(for: f))
            } else {
                _ = d.refresh(at: self.field(for: f))
            }
        case let .remove(f):
            if player is MuehleScene {
                d.needsRefresh(at: self.field(for: f))
            } else {
                let sec = d.refresh(at: self.field(for: f))
                sleep(UInt32(sec) + 1)
            }
        case let .move(from: from, to: to):
            if player is MuehleScene {
                d.moved(from: self.field(for: from), to: self.field(for: to))
            } else {
                let sec = d.move(from: self.field(for: from), to: self.field(for: to))
                sleep(UInt32(sec) + 1)
            }
        }
    }
}

extension Game {
    
    /// Die Spielfarben von Mühle
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
    }
}

// Gameplay {
extension Game {
    
    /// Die Spielphasen von Mühle
    ///
    /// - placing: Wenn Steine im Spiel gesetzt werden
    /// - moving: Wenn Steine von dem Spieler zu ihren Nachbarfelderen bewegt werden können
    /// - remove: Wenn ein Steine vom anderen Spieler entfernt wird
    /// - jumping: Wenn Steine zu beliebigen Positionen bewegt werden können
    /// - winner: Wenn ein Spieler gewonnen hat
    /// - draw: Wenn das Spiel unentschieden endet
    public enum Phase {
        /// as: Die Spielfarbe des Spielers, der den nächsten Stein setzen darf
        /// leftStones: Wie viele Steine jedem Spieler noch zur Verfügung stehen
        case placing(as: Game.Color, leftStones: (white: Int, black: Int))
        /// as: Die Spielfarbe des Spielers, der den nächsten Stein bewegen darf
        case moving(as: Game.Color)
        /// as: Die Spielfarbe des Spielers, der den nächsten Stein wegnehmen darf
        case remove(as: Game.Color)
        /// as: Die Spielfarbe des Spielers, der den nächsten Stein bewegen darf
        case jumping(for: Game.Color)
        
        /// Die Spielfarbe des Spielers, der gewonnen hat
        case winner(Color)
        case draw
        
        /// Die Spielfarbe, die gerade am Zug ist.
        /// - Returns: Nil only for ended game
        func playingColor() -> Game.Color? {
            switch self {
            case .placing(as: let c, _), .moving(as: let c), .remove(as: let c), .jumping(for: let c):
                return c
            case .winner(_),.draw:
                return nil
            }
        }
    }
}

extension Game.Phase: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case color
        case leftStones
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .draw:
            try container.encode("D", forKey: .type)
        case let .winner(c):
            try container.encode("W", forKey: .type)
            try container.encode(c, forKey: .color)
        case let .moving(as: c):
            try container.encode("M", forKey: .type)
            try container.encode(c, forKey: .color)
        case let .remove(as: c):
            try container.encode("R", forKey: .type)
            try container.encode(c, forKey: .color)
        case let .jumping(for: c):
            try container.encode("J", forKey: .type)
            try container.encode(c, forKey: .color)
        case let .placing(as: c, leftStones: left):
            try container.encode("P", forKey: .type)
            try container.encode(c, forKey: .color)
            try container.encode(left.white*10+left.black, forKey: .leftStones)
        }
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let t = try container.decode(String.self, forKey: .type)
        
        func color() throws -> Game.Color {
            return try container.decode(Game.Color.self, forKey: .color)
        }
        
        switch t {
        case "D":
            self = .draw
        case "W":
            self = .winner(try color())
        case "M":
            self = .moving(as: try color())
        case "R":
            self = .remove(as: try color())
        case "J":
            self = .jumping(for: try color())
        case "P":
            let left = try container.decode(Int.self, forKey: .leftStones)
            self = .placing(as: try color(), leftStones: (white: left / 10, black: left % 10))
        default:
            throw PhaseError.wrongTypeIdentifier(t)
        }
    }
    enum PhaseError: Error {
        case wrongTypeIdentifier(String)
    }
}

extension Game {
    /// Beschreibt alle möglichen Züge eines Spielers
    ///
    /// - place: Beschreibt Züge, bei denen der Spieler Steine setzen darf
    /// - move: Beschreibt Züge, bei denen der Spieler Steine bewegen darf
    /// - remove: Beschreibt Züge, bei denen der Spieler Steine, des anderen Spielers, wegnehmen darf
    /// - noMove: Wenn keine Züge mehr möglich sind
    public enum PossibleMove {
        case place(inEither: [MuehleField], left: Int)
        case move([(from: MuehleField, to: [MuehleField])])
        case remove(either: [MuehleField])
        
        case noMove
        
        /// Wandelt mögliche Züge in echte Züge um
        ///
        /// - Returns: Alle Züge, die vom Spieler durchgeführt werden dürfen
        public func convertToMoves() -> [Move] {
            switch self {
            case .place(inEither: let all, left: _):
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
            case .place(inEither: let all, left: _):
                return !all.isEmpty
            case .move(let all):
                return all.first(where: { return !$0.to.isEmpty }) != nil
            case .remove(either: let all):
                return !all.isEmpty
            case .noMove:
                return false
            }
        }
        
        /// Gibt zurück, ob dieses Feld ein mögliches Ursprungsfeld für einen Zug ist
        public func contains(from: MuehleField) -> Bool {
            switch self {
            case .place(inEither: let all, left: _):
                return all.contains(from)
            case .move(let all):
                return all.contains(where: { return $0.from == from })
            case .remove(either: let all):
                return all.contains(from)
            case .noMove:
                return false
            }
        }
        /// Gibt zurück, ob das to-Feld ein mögliches Zielfeld für das Ursprungsfeld from ist
        public func contains(to: MuehleField, with from: MuehleField) -> Bool {
            switch self {
            case .place(inEither: let all, left: _):
                return all.contains(to)
            case .move(let all):
                return all.first(where: { return $0.from == from })?.to.contains(to) ?? false
            case .remove(either: let all):
                return all.contains(to)
            case .noMove:
                return false
            }
        }
        
        /// Gibt den Zug für ein bestimmtes Ursprungs- und Zielfeld zurück
        public func getMove(from: MuehleField, to: MuehleField) -> Game.Move? {
            switch self {
            case .place(inEither: let all, left: _):
                guard from == to else {
                    return nil
                }
                guard all.contains(from) else {
                    return nil
                }
                return Game.Move.place(in: from)
            case .move(let all):
                guard from != to else {
                    return nil
                }
                guard all.first(where: { return $0.from == from })?.to.contains(to) ?? false else {
                    return nil
                }
                return Game.Move.move(from: from, to: to)
            case .remove(either: let all):
                guard from == to else {
                    return nil
                }
                guard all.contains(from) else {
                    return nil
                }
                return Game.Move.remove(from)
            case .noMove:
                return nil
            }
        }
    }
    
    /// Gibt alle möglichen Züge für die gegebene Spielphase zurück
    func possibleMoves(for phase: Phase) -> PossibleMove {
        switch phase {
        case let .placing(as: c, leftStones: (white: w, black: b)):
            return PossibleMove.place(inEither: self.emptyFields, left: c == .white ? w : b)
        case .moving(as: let c):
            var all: [(from: MuehleField, to: [MuehleField])] = []
            for p in self.fields(for: c) {
                let next = self.fields(nextTo: p).filter({ return $0.state == .empty }).map({ return MuehleField(field: $0) })
                guard !next.isEmpty else { continue }
                all.append((from: MuehleField(field: p), to: next))
            }
            guard !all.isEmpty else {
                return PossibleMove.noMove
            }
            return PossibleMove.move(all)
        case .jumping(for: let c):
            var all: [(from: MuehleField, to: [MuehleField])] = []
            let empty = self.emptyFields
            for p in self.fields(for: c) {
                all.append((from: MuehleField(field: p), to: empty))
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
                // Alle gegnerischen Steine sind in einer Mühle. Also darf jeder Stein entfernt werden
                return PossibleMove.remove(either: all.asMuehleFields())
            }
            return PossibleMove.remove(either: filteredForMühle.asMuehleFields())
        case .draw, .winner(_):
            return .noMove
        }
    }
}

extension Game {
    /// Eine Version von Mühle Feldern (Field), die Spielübergreifend verwendet werden kann
    public struct MuehleField: Equatable {
        public let id: Int
        public let state: Field.State
        
        init(field: Field) {
            self.id = field.id
            self.state = field.state
        }
        
        public static func ==(lhs: MuehleField, rhs: MuehleField) -> Bool {
            return lhs.id == rhs.id
        }
    }
    func field(for other: MuehleField) -> Field {
        return self.fields[other.id]
    }
    func row(for field: MuehleField) -> Int {
        return self.fields[field.id].row
    }
    func column(for field: MuehleField) -> Int {
        return self.fields[field.id].column
    }
}

extension Game {
    
    /// Ein Spielzug
    ///
    /// - place: Ein Stein wird in das gegebene Feld plaziert
    /// - move: Ein Stein wird vom Ursprungsfeld (from) zum Zielfeld bewegt (to)
    /// - remove: Ein Stein wird vom einem Feld entfernt
    public enum Move: Equatable {
        case place(in: MuehleField)
        case move(from: MuehleField, to: MuehleField)
        case remove(MuehleField)
        
        public static func ==(lhs: Game.Move, rhs: Game.Move) -> Bool {
            switch (lhs,rhs) {
            case let (.place(in: l),.place(in: r)):
                return l == r
            case let (.move(from: fL, to: tL),.move(from: fR, to: tR)):
                return fL == fR && tL == tR
            case let (.remove(l),.remove(r)):
                return l == r
            default:
                return false
            }
        }
    }
}

// MARK: Spiel speichern
extension Game: Encodable {
    private enum CodingKeys: String, CodingKey {
        case states
        case phase
        case white
        case black
    }
    enum PlayerType: RawRepresentable, Codable {
        case smart(depth: Int)
        case random
        case user
        case scene
        
        typealias RawValue = String
        var rawValue: String {
            switch self {
            case let .smart(depth: d):
                return "smart\(d)"
            case .random:
                return "random"
            case .user:
                return "user"
            case .scene:
                return "scene"
            }
        }
        
        init?(rawValue: String) {
            switch rawValue {
            case var str where str.hasPrefix("smart"):
                str.removeSubrange(..<str.index(str.startIndex, offsetBy: 5))
                guard let num = Int(str) else {
                    return nil
                }
                self = .smart(depth: num)
            case "random":
                self = .random
            case "user":
                self = .user
            case "scene":
                self = .scene
            default:
                return nil
            }
        }
        
        init?(player: Player) {
            switch player {
            case _ as RandomPlayer:
                self = .random
            case _ as UserPlayer:
                self = .user
            case _ as MuehleScene:
                self = .scene
            case let p as SmartPlayer:
                self = .smart(depth: p.levels)
            default:
                return nil
            }
        }
        
        func player(color: Game.Color, scene: (Game.Color) -> MuehleScene) -> Player {
            switch self {
            case .smart(depth: let d):
                return SmartPlayer(color: color, numLevels: d)
            case .random:
                return RandomPlayer(color: color)
            case .user:
                return UserPlayer(color: color)
            case .scene:
                return scene(color)
            }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.fieldStates, forKey: .states)
        
        if self.currentPhase == nil {
            print("No phase")
        }
        try container.encodeIfPresent(self.currentPhase, forKey: .phase)
        
        try container.encodeIfPresent(PlayerType(player: self.whitePlayer), forKey: .white)
        try container.encodeIfPresent(PlayerType(player: self.blackPlayer), forKey: .black)
    }
    
    struct DecodableGame: Decodable {
        let states: [Field.State]
        let phase: Game.Phase
        let whiteType: PlayerType
        let blackType: PlayerType
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.states = try container.decode([Field.State].self, forKey: .states)
            self.phase = try container.decode(Game.Phase.self, forKey: .phase)
            
            self.whiteType = try container.decode(PlayerType.self, forKey: .white)
            self.blackType = try container.decode(PlayerType.self, forKey: .black)
        }
    }
    func archived() throws -> Data {
        let encoder = JSONEncoder()
        
        return try encoder.encode(self)
    }
    static func unarchived(from data: Data, with scene: (Game.Color) -> MuehleScene) throws -> (phase: Game.Phase, game: Game) {
        let decoder = JSONDecoder()
        
        let value = try decoder.decode(DecodableGame.self, from: data)
        
        
        return try Game.game(from: value, with: scene)
    }
    
    static func game(from decodable: DecodableGame, with scene: (Game.Color) -> MuehleScene) throws -> (phase: Game.Phase, game: Game) {
        let white = decodable.whiteType.player(color: Game.Color.white, scene: scene)
        let black = decodable.blackType.player(color: Game.Color.black, scene: scene)
        
        let game = Game(white: white, black: black)
        
        guard game.fields.count == decodable.states.count else {
            throw GameDecodingError.wrongNumberOfStates
        }
        for i in 0..<game.fields.count {
            game.fields[i].state = decodable.states[i]
        }
        
        return (decodable.phase, game)
    }
    
    enum GameDecodingError: Error {
        case wrongNumberOfStates
    }
}

// MARK: - Spiel ohne Ausgabe
public class GameNoOutput: Game {
    public override var loggingEnabled: Bool {
        get {
            return false
        }
        set { }
    }
    public override func log(_ str: String) {
        
    }
    override var keepHistory: Bool {
        get {
            return false
        }
        set { }
    }
}

// MARK: - Output

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
    }
}
