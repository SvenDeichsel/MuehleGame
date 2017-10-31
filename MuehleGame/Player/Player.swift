//
//  Player.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 07.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

/**
 Das Player protocol definiert, was ein "Player" object zur Verfügung stellen muss, damit es Mühle spielen kann.
 */
public protocol Player: class {
    
    /// Diese Methode wird vom Spiel aufgerufen, um den nächsten Zug des Spielers zu erfahren. Wenn nil zurückgegeben wird oder ein Zug, der nicht möglich ist, dann wird das Spiel vom Player aufgegeben.
    ///
    /// - Parameters:
    ///   - possible: Alle möglichen Züge
    ///   - phase: Die Phase in der das Spiel sich gerade befindet
    ///   - previous: Die vorherige Phase, falls phase .removing ist.
    ///   - game: Das Spiel, was gerade gespielt wird
    /// - Returns: Den Zug, den der Spieler durchführen möchte.
    func chooseMove(from possible: Game.PossibleMove, phase: Game.Phase, previous: Game.Phase?, in game: Game) -> Game.Move?
    
    
    /// Wird aufgerufen, wenn der Spieler gewonnen hat.
    ///
    /// - Parameter game: Das gewonnene Spiel
    func won(game: Game)
    
    
    /// Wird aufgerufen, wenn der Spieler verloren hat.
    ///
    /// - Parameter game: Das verlorene Spiel
    func lost(game: Game)
    
    /// Wird aufgerufen, wenn das Spiel unentschieden endet
    ///
    /// - Parameter game: Das unentschiedene Spiel
    func draw(game: Game)
}

extension Player {
    func chooseMove(from possible: Game.PossibleMove, phase: Game.Phase, in game: Game) -> Game.Move? {
        return self.chooseMove(from: possible, phase: phase, previous: nil, in: game)
    }
}

/**
 Ein Spieler, welcher vom Spiel erzeugt werden kann.
 */
public protocol InitializablePlayer: Player {
    init(color: Game.Color)
}
