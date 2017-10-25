//
//  RandomPlayer.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 19.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

final public class RandomPlayer: InitializablePlayer {
    let color: Game.Color
    
    public init(color: Game.Color) {
        self.color = color
    }
    
    public func chooseMove(from possible: Game.PossibleMove, in game: Game) -> Game.Move? {
        let all = possible.convertToMoves()
        
        guard let move = all.random() else {
            return nil
        }
        
        return move.element
    }
    
    public func won(game: Game) {
        print("\(color.description) won")
    }
    public func lost(game: Game) {
        print("\(color.description) lost")
    }
    public func draw(game: Game) {
        
    }
}

