//
//  UserPlayer.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 25.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

class UserPlayer: Player {
    let color: Game.Color
    
    init(color: Game.Color) {
        self.color = color
    }
    
    func chooseMove(from possible: Game.PossibleMove, in game: Game) -> Game.Move? {
        print("Current game state")
        print(game.description)
        print("Choose a move (for: \(self.color.description))")
        let all = possible.convertToMoves()
        for (i,move) in all.enumerated() {
            print("\(i+1): \(move)")
        }
        var chosenMove: Int?
        while chosenMove == nil {
            if let input = readLine() {
                if let num = Int(input), num > 0 && num <= all.count {
                    chosenMove = num
                }
            } else {
                return nil
            }
        }
        guard let moveInt = chosenMove else {
            return nil
        }
        return all.element(at: moveInt - 1)
    }
    
    func won(game: Game) {
        print("You won")
    }
    
    func lost(game: Game) {
        print("You lost")
    }
    
    func draw(game: Game) {
        print("Draw")
    }
    
    
}
