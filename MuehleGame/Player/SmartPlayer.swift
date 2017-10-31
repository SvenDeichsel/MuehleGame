//
//  SmartPlayer.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 19.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

/**
 Der SmartPlayer bestimmt den nächsten Zug, indem er mehrere Züge in die Zukunft berechnet und dann den besten nächsten Zug auswählt
 */
open class SmartPlayer: InitializablePlayer {
    let ownColor: Game.Color
    let otherColor: Game.Color
    
    private let scorer: GameBoardScorer
    
    public let levels: Int
    private var currentLevels: Int
    
    public required init(color: Game.Color) {
        self.ownColor = color
        self.otherColor = color.opposite
        
        self.scorer = GameBoardScorer(color: color)
        self.levels = 4
        self.currentLevels = 4
    }
    public required init(color: Game.Color, numLevels: Int) {
        self.ownColor = color
        self.otherColor = color.opposite
        
        self.scorer = GameBoardScorer(color: color)
        self.levels = numLevels
        self.currentLevels = numLevels
    }
    
    public func setLevels(for phase: Game.Phase) {
        switch phase {
        case let .placing(as: _, leftStones: (white: _, black: b)):
            if b >= 3 {
                self.currentLevels = min(self.levels, 4)
            } else {
                self.currentLevels = min(self.levels, 5)
            }
        case .jumping(for: _):
            self.currentLevels = min(self.levels, 5)
        case .remove(as: _):
            break
        default:
            self.currentLevels = self.levels
        }
    }
    
    public func chooseMove(from possible: Game.PossibleMove, phase: Game.Phase, previous: Game.Phase?, in game: Game) -> Game.Move? {
        
        self.setLevels(for: phase)
        
        //let start = Date()
        /*
         let selected = self.scorer.selectMoveMinMax(for: possible, phase: phase, game: game, levels: self.currentLevels)
         print("Selecting move took \(Date().timeIntervalSince(start)) seconds")
         start = Date()
         */
        //let selectedOld = self.scorer.chooseMove(from: possible, phase: phase, game: game)
        let selectedAlphaBeta = self.scorer.selectMoveAlphaBeta(for: possible, phase: phase, game: game, levels: self.currentLevels)
        //print("AlphaBeta took \(Date().timeIntervalSince(start)) seconds")
        
        //print("Standard:\n\(selected)\nAlphaBeta:\n\(selectedAlphaBeta)\nMoves equal: \(selected == selectedAlpha)")
        return selectedAlphaBeta.random()?.element
    }
    
    public func chooseMoveAlphaBeta(from possible: Game.PossibleMove, phase: Game.Phase, previous: Game.Phase?, in game: Game) -> Game.Move? {
        self.setLevels(for: phase)
        
        return self.scorer.selectMoveAlphaBeta(for: possible, phase: phase, game: game, levels: self.currentLevels, previousPhase: previous).random()?.element
    }
    public func chooseMoveMinMax(from possible: Game.PossibleMove, phase: Game.Phase, previous: Game.Phase?, in game: Game) -> Game.Move? {
        self.setLevels(for: phase)
        
        return self.scorer.selectMoveMinMax(for: possible, phase: phase, game: game, levels: self.currentLevels, previousPhase: previous).random()?.element
    }
    
    open func won(game: Game) {
        print("Smart player \(ownColor) won")
    }
    
    open func lost(game: Game) {
        print("Smart player \(ownColor) lost")
    }
    
    open func draw(game: Game) {
        print("Smart player draw")
    }
}

// MARK: Others

struct MoveScore {
    let move: Game.Move
    let score: Int
    
    init(move: Game.Move, game: Game, color: Game.Color) {
        self.move = move
        self.score = game.evaluate(move: move, for: color)
    }
}

class GameBoardScorer {
    private let calculatingGame: Game
    
    let groupIndices = SmartPlayer.fieldGroupIndices
    var scoreColor: Game.Color
    
    let directNeighbors: [[Int]]
    
    init(color: Game.Color) {
        let game = GameNoOutput(whiteType: RandomPlayer.self, blackType: RandomPlayer.self)
        self.calculatingGame = game
        self.scoreColor = color
        
        self.directNeighbors = game.fields.map({ (field) -> [Int] in
            return field.sepetatedByOneFields.map({ return $0.id })
        })
    }
    
    func chooseMove(from possible: Game.PossibleMove, phase: Game.Phase, game: Game) -> [Game.Move] {
        let scores = self.scoreMoves(possible: possible, phase: phase, game: game)
        
        var maxScore: Double = -Double.infinity
        var maxMoves: [Game.Move] = []
        
        for value in scores {
            if value.score == maxScore {
                maxMoves.append(value.move)
            } else if value.score > maxScore {
                maxScore = value.score
                maxMoves = [value.move]
            }
        }
        
        return maxMoves
    }
    
    func applyStatesOnGame(_ states: [Field.State]) {
        for (i,field) in self.calculatingGame.fields.enumerated() {
            field.state = states[i]
        }
    }
    func nextGameStates(for current: [Field.State], phase: Game.Phase, previousPhase: Game.Phase? = nil) -> [(states: [Field.State], phase: Game.Phase, previous: Game.Phase?)] {
        switch phase {
        case .draw, .winner(_):
            return [(current, phase, nil)]
        default:
            self.applyStatesOnGame(current)
            let allAvailable = self.calculatingGame.possibleMoves(for: phase).convertToMoves()
            var value: [(states: [Field.State], phase: Game.Phase, previous: Game.Phase?)] = []
            for move in allAvailable {
                self.applyStatesOnGame(current)
                let next = self.calculatingGame.perform(move: move, currentPhase: phase)
                guard next.success else { continue }
                let newStates = self.calculatingGame.fieldStates
                if let nextPhase = next.nextPhase {
                    value.append((newStates,nextPhase,phase))
                } else {
                    let nextPhase = calculatingGame.nextPhase(for: previousPhase ?? phase)
                    value.append((newStates,nextPhase,nil))
                }
            }
            return value
        }
    }
    
    func scoreMoves(possible: Game.PossibleMove, phase: Game.Phase, game: Game) -> [(score: Double, move: Game.Move)] {
        let current = game.fieldStates
        //let currentValues = self.values(for: current)
        var result: [(score: Double, move: Game.Move)] = []
        let allMoves = possible.convertToMoves()
        for move in allMoves {
            self.applyStatesOnGame(current)
            let next = self.calculatingGame.perform(move: move, currentPhase: phase)
            guard next.success else { continue }
            let newStates = self.calculatingGame.fieldStates
            let futureGameState: (states: [Field.State], phase: Game.Phase)
            if let nextPhase = next.nextPhase {
                futureGameState = (newStates, nextPhase)
            } else {
                let nextPhase = calculatingGame.nextPhase(for: phase)
                futureGameState = (newStates, nextPhase)
            }
            let levels: Int
            switch (futureGameState.phase,phase) {
            case (.placing(_),_),(_,.placing(_)):
                levels = 2
            case (.jumping(_),.jumping(_)):
                levels = 2
            case (.jumping(_),_),(_,.jumping(_)):
                levels = 2
            default:
                levels = 4
            }
            let score = self.scoreForNext(states: futureGameState.states, phase: futureGameState.phase, level: levels)
            
            result.append((score,move))
        }
        return result
    }
    
    func scoreForNext(states: [Field.State], phase: Game.Phase, level: Int) -> Double {
        // Values for finished game
        switch phase {
        case let .winner(c):
            if c == self.scoreColor {
                return Double.infinity
            } else {
                return -Double.infinity
            }
        case .draw:
            return 0.0
        default:
            break
        }
        guard level > 0 else {
            return self.score(for: states)
        }
        guard let color = phase.playingColor() else {
            return self.score(for: states)
        }
        let next = self.advanceByOneMove([(states,phase)])
        let scores = next.map({ return self.scoreForNext(states: $0.states, phase: $0.phase, level: level - 1)})
        if color == self.scoreColor {
            return scores.max() ?? -Double.infinity
        } else {
            return scores.min() ?? -Double.infinity
        }
    }
    func advanceByOneMove(_ value: [(states: [Field.State], phase: Game.Phase)], filter: Bool = false) -> [(states: [Field.State], phase: Game.Phase)] {
        var new: [(states: [Field.State], phase: Game.Phase)] = []
        for cur in value {
            let next = self.nextGameStates(for: cur.states, phase: cur.phase)
            if filter && next.count > 3 {
                
            } else {
                new.append(contentsOf: next.map({ return ($0.states,$0.phase) }))
            }
        }
        return new
    }
}

// MARK: - Scoring
extension GameBoardScorer {
    struct ScoreValues {
        let numOwn: Int
        let numOther: Int
        let numOwnMühle: Int
        let numOtherMühle: Int
        
        static func +(lhs: ScoreValues, rhs: ScoreValues) -> ScoreValues {
            return ScoreValues(numOwn: lhs.numOwn + rhs.numOwn, numOther: lhs.numOther + rhs.numOther, numOwnMühle: lhs.numOwnMühle + rhs.numOwnMühle, numOtherMühle: lhs.numOtherMühle + rhs.numOtherMühle)
        }
        static func +=(lhs: inout ScoreValues, rhs: ScoreValues) {
            lhs = ScoreValues(numOwn: lhs.numOwn + rhs.numOwn, numOther: lhs.numOther + rhs.numOther, numOwnMühle: lhs.numOwnMühle + rhs.numOwnMühle, numOtherMühle: lhs.numOtherMühle + rhs.numOtherMühle)
        }
    }
    
    func values(for states: [Field.State]) -> ScoreValues {
        let totalOwn = states.reduce(into: 0) { (n, state) in
            guard state == .filled(color: self.scoreColor) else {
                return
            }
            n += 1
        }
        let totalOther = states.reduce(into: 0) { (n, state) in
            guard state == .filled(color: self.scoreColor.opposite) else {
                return
            }
            n += 1
        }
        
        var numOwnMühle: Int = 0
        var numOtherMühle: Int = 0
        
        for group in self.groupIndices {
            let groupStates: [Field.State] = group.map({ return states[$0] })
            
            if groupStates.only(matching: { return $0 == .filled(color: self.scoreColor) }) {
                numOwnMühle += 1
            } else if groupStates.only(matching: { return $0 == .filled(color: self.scoreColor.opposite) }) {
                numOtherMühle += 1
            }
        }
        
        return ScoreValues(numOwn: totalOwn, numOther: totalOther, numOwnMühle: numOwnMühle, numOtherMühle: numOtherMühle)
    }
    func scoreNew(for states: [Field.State]) -> Double {
        var numOwnTotal: Int = 0
        var numOtherTotal: Int = 0
        var numEmpty: Int = 0
        
        var numOwnMoves: Int = 0
        var numOtherMoves: Int = 0
        for (id,state) in states.enumerated() {
            if case .filled(color: let c) = state {
                if c == self.scoreColor {
                    numOwnTotal += 1
                    numOwnMoves += self.directNeighbors[id].count(where: { return states[$0] == .empty })
                } else {
                    numOtherTotal += 1
                    numOtherMoves += self.directNeighbors[id].count(where: { return states[$0] == .empty })
                }
            } else {
                numEmpty += 1
            }
        }
        if numOwnTotal == 3 {
            numOwnMoves = numEmpty * 3
        }
        if numOtherTotal == 3 {
            numOtherMoves = numEmpty * 3
        }
        var numOwnClosedMuhle: Int = 0
        var numOwnOpenMuhle: Int = 0
        var numOtherClosedMuhle: Int = 0
        var numOtherOpenMuhle: Int = 0
        
        for group in self.groupIndices {
            var numOwn = 0
            var numOther = 0
            for id in group {
                if case .filled(color: let c) = states[id] {
                    if c == self.scoreColor {
                        numOwn += 1
                    } else {
                        numOther += 1
                    }
                }
            }
            if numOwn == 3 {
                numOwnClosedMuhle += 1
            } else if numOther == 3 {
                numOtherClosedMuhle += 1
            } else if numOwn == 2 && numOther == 0 {
                if let free = group.first(where: { return states[$0] == .empty }) {
                    if self.directNeighbors[free].contains(where: { return !group.contains($0) && states[$0] == .filled(color: self.scoreColor) }) {
                        numOwnOpenMuhle += 1
                    }
                }
            } else if numOther == 2 && numOwn == 0 {
                if let free = group.first(where: { return states[$0] == .empty }) {
                    if self.directNeighbors[free].contains(where: { return !group.contains($0) && states[$0] == .filled(color: self.scoreColor.opposite) }) {
                        numOtherOpenMuhle += 1
                    }
                }
            }
        }
        
        let stoneScore: Double = Double((numOwnTotal-numOtherTotal)*100)
        let mühleScore: Double = Double((numOwnOpenMuhle+numOwnClosedMuhle)-(numOtherOpenMuhle-numOtherClosedMuhle)) * 10
        let movingScore: Double = Double(numOwnMoves-numOtherMoves)
        
        return stoneScore + mühleScore + movingScore
        
        /*
        var score: Double = 0.0
        
        // Eigene Steine
        if numOwnTotal > 3 {
            score += 0.05 + 0.05 * Double(numOwnTotal - 3)
        }
        // Andere Steine
        if numOtherTotal > 3 {
            score -= 0.05 + 0.05 * Double(numOtherTotal - 3)
        }
        // Zugmöglichkeiten
        func amount(for numMoves: Int) -> Double {
            switch numMoves {
            case 2,3:
                return 0.1
            case 4,5:
                return 0.15
            case 6,7:
                return 0.2
            case 8,9:
                return 0.25
            case let x where x > 9:
                return 0.3
            default:
                return 0.0
            }
        }
        score += amount(for: numOwnMoves)
        score -= amount(for: numOtherMoves)
        
        // Geschlossene Mühlen
        if numOwnClosedMuhle == 1 {
            score += 0.01
        } else if numOwnClosedMuhle > 1 {
            score += 0.02
        }
        if numOtherClosedMuhle == 1 {
            score -= 0.01
        } else if numOtherClosedMuhle > 1 {
            score -= 0.02
        }
        
        // Offene Mühlen
        if numOwnOpenMuhle == 1 {
            score += 0.02
        } else if numOwnOpenMuhle > 1 {
            score += 0.04
        }
        if numOtherOpenMuhle == 1 {
            score -= 0.02
        } else if numOtherOpenMuhle > 1 {
            score -= 0.04
        }
        
        // Bewegungsfreiheit
        let difMoves = numOwnMoves - numOtherMoves
        switch difMoves {
        case let x where x < -6:
            score -= 0.16
        case -4,-5,-6:
            score -= 0.08
        case -2,-3:
            score -= 0.04
        case -1:
            score -= 0.02
        case 1:
            score += 0.02
        case 2,3:
            score += 0.04
        case 4,5,6:
            score += 0.08
        case let x where x > 6:
            score += 0.16
        default:
            break
        }
        return score
        */
    }
    func score(for states: [Field.State]) -> Double {
        let val = self.values(for: states)
        
        return Double((val.numOwnMühle - val.numOtherMühle) * 10 + (val.numOwn - val.numOther))
    }
    func score(for states: [Field.State], currentValues: ScoreValues) -> Double {
        let val = self.values(for: states)
        
        let difOwnStones = currentValues.numOwn - val.numOwn
        let difOtherStones = currentValues.numOther - val.numOther
        
        let difOwnMühle = currentValues.numOwnMühle - val.numOwnMühle
        let difOtherMühle = currentValues.numOtherMühle - currentValues.numOtherMühle
        
        return Double((difOwnStones - difOtherStones) * 100 + (difOwnMühle - difOtherMühle) * 10 + (val.numOwnMühle - val.numOtherMühle) * 10 + (val.numOwn - val.numOther))
    }
}

// MARK: - Max Min
extension GameBoardScorer {
    func selectMoveMinMax(for possible: Game.PossibleMove, phase: Game.Phase, game: Game, levels: Int, previousPhase: Game.Phase? = nil) -> [Game.Move] {
        var bestScore: Double = -Double.infinity
        var bestMoves: [Game.Move] = []
        
        let current = game.fieldStates
        
        let all = possible.convertToMoves()
        
        guard let color = phase.playingColor() else {
            return []
        }
        let useMax = color == self.scoreColor
        if !useMax { bestScore = Double.infinity }
        
        for move in all {
            self.applyStatesOnGame(current)
            
            let next = self.calculatingGame.perform(move: move, currentPhase: phase)
            guard next.success else { continue }
            
            let nextStates = self.calculatingGame.fieldStates
            
            if let p = next.nextPhase {
                if useMax {
                    let score = self.minmax(states: nextStates, phase: p, level: levels - 1)
                    if score > bestScore {
                        bestScore = score
                        bestMoves = [move]
                    } else if score == bestScore {
                        bestMoves.append(move)
                    }
                } else {
                    let score = self.minmax(states: nextStates, phase: p, level: levels - 1)
                    if score < bestScore {
                        bestScore = score
                        bestMoves = [move]
                    } else if score == bestScore {
                        bestMoves.append(move)
                    }
                }
                continue
            }
            
            let nextPhase: Game.Phase = self.calculatingGame.nextPhase(for: previousPhase ?? phase)
            
            if useMax {
                let score = self.minmax(states: nextStates, phase: nextPhase, level: levels - 1)
                if score > bestScore {
                    bestScore = score
                    bestMoves = [move]
                } else if score == bestScore {
                    bestMoves.append(move)
                }
            } else {
                let score = self.minmax(states: nextStates, phase: nextPhase, level: levels - 1)
                if score < bestScore {
                    bestScore = score
                    bestMoves = [move]
                } else if score == bestScore {
                    bestMoves.append(move)
                }
            }
        }
        return bestMoves
    }
    func minmax(states: [Field.State], phase: Game.Phase, level: Int) -> Double {
        // Values for finished game
        switch phase {
        case let .winner(c):
            if c == self.scoreColor {
                return Double.infinity
            } else {
                return -Double.infinity
            }
        case .draw:
            return 0.0
        default:
            break
        }
        guard level > 0 else {
            return self.score(for: states)
        }
        guard let color = phase.playingColor() else {
            return self.score(for: states)
        }
        let useMAX = color == self.scoreColor
        
        var best: Double = useMAX ? -Double.infinity : Double.infinity
        
        let next = self.nextGameStates(for: states, phase: phase)
        
        for value in next {
            let val: Double = self.minmax(states: value.states, phase: value.phase, level: level - 1)
            if useMAX {
                if val > best {
                    best = val
                }
            } else {
                if val < best {
                    best = val
                }
            }
        }
        return best
    }
}

// MARK: - AlphaBeta
extension GameBoardScorer {
    func selectMoveAlphaBeta(for possible: Game.PossibleMove, phase: Game.Phase, game: Game, levels: Int, previousPhase: Game.Phase? = nil) -> [Game.Move] {
        let alpha: Double = -Double.infinity
        let beta: Double = Double.infinity
        
        var bestScore: Double = -Double.infinity
        var bestMoves: [Game.Move] = []
        
        let current = game.fieldStates
        guard let currentColor = phase.playingColor() else {
            return []
        }
        
        let all = possible.convertToMoves()
        var scores: [Double] = [Double].init(repeating: .nan, count: all.count)
        for (i,move) in all.enumerated() {
            self.applyStatesOnGame(current)
            
            let next = self.calculatingGame.perform(move: move, currentPhase: phase)
            guard next.success else { continue }
            
            let nextStates = self.calculatingGame.fieldStates
            
            if let p = next.nextPhase {
                let score: Double
                if currentColor != self.scoreColor {
                    score = self.alphaBeta(states: nextStates, phase: p, level: levels - 1, alpha: alpha, beta: beta, previousPhase: phase)
                } else {
                    score = -self.alphaBeta(states: nextStates, phase: p, level: levels - 1, alpha: alpha, beta: beta, previousPhase: phase)
                }
                if score > bestScore {
                    bestScore = score
                    bestMoves = [move]
                } else if score == bestScore {
                    bestMoves.append(move)
                }
                scores[i] = score
                continue
            }
            let nextPhase: Game.Phase = self.calculatingGame.nextPhase(for: previousPhase ?? phase)
            
            let score: Double
            if currentColor != self.scoreColor {
                score = self.alphaBeta(states: nextStates, phase: nextPhase, level: levels - 1, alpha: alpha, beta: beta)
            } else {
                score = -self.alphaBeta(states: nextStates, phase: nextPhase, level: levels - 1, alpha: alpha, beta: beta)
            }
            if score > bestScore {
                bestScore = score
                bestMoves = [move]
            } else if score == bestScore {
                bestMoves.append(move)
            }
            scores[i] = score
        }
        //print(scores)
        return bestMoves
    }
    func alphaBeta(states: [Field.State], phase: Game.Phase, level: Int, alpha: Double, beta: Double, previousPhase: Game.Phase? = nil) -> Double {
        // Values for finished game
        switch phase {
        case .winner(_):
            //print("Calculated winner")
            return Double.infinity
        case .draw:
            return 0.0
        default:
            break
        }
        guard level > 0 else {
            return self.score(for: states)
        }
        //let currentColor = phase.playingColor()!
        var a = alpha
        
        let next = self.nextGameStates(for: states, phase: phase, previousPhase: previousPhase)
        
        var allValues: [Double] = []
        for value in next {
            let val: Double = -self.alphaBeta(states: value.states, phase: value.phase, level: level - 1, alpha: -beta, beta: -a, previousPhase: value.previous)
            /*if currentColor != self.scoreColor {
                val = self.alphaBeta(states: value.states, phase: value.phase, level: level - 1, alpha: a, beta: beta)
            } else {
                val = -self.alphaBeta(states: value.states, phase: value.phase, level: level - 1, alpha: -beta, beta: -a)
            }*/
            allValues.append(val)
            if val >= beta {
                guard beta.isFinite else {
                    //print("\(alpha), \(beta), \(val)")
                    return beta
                }
                return beta
            }
            if val > a {
                a = val
            }
        }
        guard a.isFinite else {
            //print("\(a), \(beta), \(allValues)")
            return a
        }
        return a
    }
}

fileprivate extension SmartPlayer {
    static var fieldGroupIndices: [[Int]] {
        get {
            var all: [[Int]] = []
            // All rows
            for i in 0..<8 {
                all.append([Int]((i*3)..<(i*3+3)))
            }
            // All columns
            all.append(contentsOf: [[0, 9, 21], [3, 10, 18], [6, 11, 15], [1, 4, 7], [16, 19, 22], [8, 12, 17], [5, 13, 20], [2, 14, 23]])
            
            return all
        }
    }
}

extension Game {
    func evaluate(move: Game.Move, for color: Game.Color) -> Int {
        switch move {
        case .place(in: let f):
            let field = self.field(for: f)
            /*
             Ranking
             1 <=> Finishes own Mühle
             2 <=> Prevents other Mühle
             3 <=> Enables Mühle on next move regardless of the other players move
             4 <=> Prevents Mühle on move after next move of the other player
             5 <=> ...
             */
            if field.wouldCompleteMühle(for: color) {
                return 1
            }
            if field.wouldCompleteMühle(for: color.opposite) {
                return 2
            }
            if let num = field.numPicesMissingForMühle(for: color) {
                if let r = num.row, let c = num.column, r == 2 && c == 2 {
                    return 3
                }
            }
            if let num = field.numPicesMissingForMühle(for: color) {
                if let r = num.row, let c = num.column, r == 2 && c == 2 {
                    return 4
                }
            }
            if let num = field.newMühleInSteps(for: color) {
                if num.row == .some(1) || num.column == .some(1) {
                    return 5
                }
            }
            if let num = field.newMühleInSteps(for: color.opposite) {
                if num.row == .some(1) || num.column == .some(1) {
                    return 6
                }
            }
            let ownCount = field.numberOfRelatedFields(with: color)
            let otherCount = field.numberOfRelatedFields(with: color.opposite)
            
            if ownCount > 2 {
                return 7
            }
            if otherCount > 3 {
                return 8
            }
            if ownCount > 0 {
                return 9
            }
            if otherCount > 0 {
                return 10
            }
            
            return 10
        case .remove(let f):
            let field = self.field(for: f)
            /*
             Ranking
             1 <=> Prevents Mühle by other player on next move
             2 <=> Frees own Mühle to be closed on next
             3 <=> Destroys Mühle of the other player
             4 <=> Frees the way to Mühle
             
             */
            if let num = field.newMühleInSteps(for: color.opposite) {
                if num.row == .some(1) || num.column == .some(1) {
                    return 1
                }
            }
            if field.wouldCompleteMühle(for: color) {
                return 2
            }
            if field.partOfMühle {
                return 3
            }
            if let num = field.newMühleInSteps(for: color) {
                if let r = num.row, r < 3 {
                    return 4
                }
                if let c = num.column, c < 3 {
                    return 5
                }
            }
            
            return 10
        case let .move(from: fromF, to: toF):
            let from = self.field(for: fromF)
            let to = self.field(for: toF)
            /*
             Ranking
             1 <=> Closes own Mühle
             2 <=> Prevents Mühle of the other player (on next move)
             3 <=> Opens own Mühle without the other player being able to close own Mühle or move in from.
             ...
             10 <=> Opens Mühle for next move for the other player
             */
            if to.wouldCompleteMühle(for: color, filledFrom: from) {
                return 1
            }
            if let num = from.newMühleInSteps(for: color.opposite) {
                if num.row == .some(1) || num.column == .some(1) {
                    return 2
                }
            }
            return 10
        }
    }
}

