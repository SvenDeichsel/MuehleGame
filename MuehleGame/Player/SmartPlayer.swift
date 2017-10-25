//
//  SmartPlayer.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 19.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

open class SmartPlayer: InitializablePlayer {
    let ownColor: Game.Color
    let otherColor: Game.Color
    
    public required init(color: Game.Color) {
        self.ownColor = color
        self.otherColor = color.opposite
    }
    
    open func chooseMove(from possible: Game.PossibleMove, in game: Game) -> Game.Move? {
        let allMoves = possible.convertToMoves()
        let scoredMoves = allMoves.map({ return MoveScore(move: $0, game: game, color: self.ownColor) })
        var dic: [Int: [MoveScore]] = [:]
        var lowest: Int? = nil
        for value in scoredMoves {
            if var old = dic[value.score] {
                old.append(value)
                dic[value.score] = old
            } else {
                dic[value.score] = [value]
            }
            if let pre = lowest {
                if value.score < pre {
                    lowest = value.score
                }
            } else {
                lowest = value.score
            }
        }
        if let low = lowest {
            return dic[low]?.random()?.element.move
        } else {
            print(dic)
            return nil
        }
    }
    
    open func won(game: Game) {
        print("Smart player \(ownColor) won")
    }
    
    open func lost(game: Game) {
        print("Smart player \(ownColor) lost")
    }
    
    open func draw(game: Game) {
        
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

extension Game {
    func evaluate(move: Game.Move, for color: Game.Color) -> Int {
        switch move {
        case .place(in: let field):
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
        case .remove(let field):
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
        case let .move(from: from, to: to):
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
            if from.wouldCompleteMühle(for: color.opposite) {
                return 2
            }
            if to.wouldCompleteMühle(for: color.opposite, filledFrom: from) {
                return 3
            }
            return 10
        }
    }
}

