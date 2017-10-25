//
//  StoneNode.swift
//  MuehleGame
//
//  Created by Sven Deichsel on 25.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import SpriteKit
import GameKit
import Foundation

class StoneNode: SKShapeNode {
    let field: Field
    
    init(field: Field, size: CGSize) {
        self.field = field
        let color: UIColor
        switch field.state {
        case .empty:
            color = .clear
        case .filled(color: .white):
            color = .white
        case .filled(color: .black):
            color = .black
        }
        super.init()
        self.path = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: size.width / 2, cornerHeight: size.height / 2, transform: nil)
        self.fillColor = color
        self.lineWidth = 0.0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
