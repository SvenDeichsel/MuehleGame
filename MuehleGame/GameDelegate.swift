//
//  GameDelegate.swift
//  MuehleGame
//
//  Created by Sven Deichsel on 25.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

protocol GameDelegate: class {
    func moved(from: Field, to: Field)
    func needsRefresh(at: Field)
    func move(from: Field, to: Field) -> TimeInterval
    func refresh(at: Field) -> TimeInterval
}
