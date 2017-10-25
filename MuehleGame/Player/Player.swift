//
//  Player.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 07.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

public protocol Player: class {
    func chooseMove(from possible: Game.PossibleMove, in game: Game) -> Game.Move?
    
    func won(game: Game)
    func lost(game: Game)
    
    func draw(game: Game)
}

public protocol InitializablePlayer: Player {
    init(color: Game.Color)
}
