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
    
    public required init(color: Game.Color) {
        self.ownColor = color
        self.otherColor = color.opposite
        
        self.scorer = GameBoardScorer(color: color)
    }
    public func chooseMove(from possible: Game.PossibleMove, phase: Game.Phase, in game: Game) -> Game.Move? {
        let start = Date()
        let selected = self.scorer.chooseMove(from: possible, phase: phase, game: game)
        print("Selecting move took \(Date().timeIntervalSince(start)) seconds")
        return selected.random()?.element
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
    private let calculatingGame: Game = GameNoOutput(whiteType: RandomPlayer.self, blackType: RandomPlayer.self)
    
    let groupIndices = SmartPlayer.fieldGroupIndices
    var scoreColor: Game.Color
    
    init(color: Game.Color) {
        self.scoreColor = color
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
    func nextGameStates(for current: [Field.State], phase: Game.Phase) -> [(states: [Field.State], phase: Game.Phase)] {
        switch phase {
        case .draw, .winner(_):
            return [(current, phase)]
        default:
            self.applyStatesOnGame(current)
            let allAvailable = self.calculatingGame.possibleMoves(for: phase).convertToMoves()
            var value: [(states: [Field.State], phase: Game.Phase)] = []
            for move in allAvailable {
                self.applyStatesOnGame(current)
                let next = self.calculatingGame.perform(move: move, currentPhase: phase)
                guard next.success else { continue }
                let newStates = self.calculatingGame.fieldStates
                if let nextPhase = next.nextPhase {
                    value.append((newStates,nextPhase))
                } else {
                    let nextPhase = calculatingGame.nextPhase(for: phase)
                    value.append((newStates,nextPhase))
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
            /*
            for i in 1...5 {
                futureGameStates = self.advanceByOneMove(futureGameStates)
                if futureGameStates.count > 10_000 / allMoves.count {
                    break
                }
                /*if i > 1 {
                    var scores: [Double] = []
                    for value in futureGameStates {
                        let score = self.score(for: value.states, currentValues: currentValues)
                        scores.append(score)
                    }
                    let top5: [(offset: Int, element: Double)]
                    if i % 2 == 0 {
                        top5 = scores.enumerated().sorted(by: { return $0.element > $1.element }).first(5)
                    } else {
                        top5 = scores.enumerated().sorted(by: { return $0.element < $1.element }).first(5)
                    }
                    var new: [(states: [Field.State], phase: Game.Phase)] = []
                    for e in top5 {
                        new.append(futureGameStates[e.offset])
                    }
                    futureGameStates = new
                }*/
            }
            */
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
            /*
            print("Total number of games calculated for \(move): \(futureGameStates.count)")
            let allScores = futureGameStates.map({ value in
                return self.score(for: value.states, currentValues: currentValues)
            })
            let max: Double = allScores.max() ?? -Double.infinity
             */
            /*
            // Avarage
            let totalScore = futureGameStates.reduce(into: 0.0, { (x, value) in
                x += self.score(for: value.states, currentValues: currentValues)
            })
            let avarageScore = totalScore / Double(futureGameStates.count)
            */
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
                new.append(contentsOf: next)
            }
        }
        return new
    }
    
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

