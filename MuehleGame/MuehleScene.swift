//
//  MuehleScene.swift
//  MuehleGame
//
//  Created by Sven Deichsel on 25.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import SpriteKit
import GameKit
import Foundation

class MuehleScene: SKScene {
    
    var game: Game = Game(whiteType: RandomPlayer.self, blackType: RandomPlayer.self)
    
    var fieldNodes: [StoneNode]
    
    var outlineNodes: [SKShapeNode]
    
    override init(size: CGSize) {
        let length = min(size.width, size.height)
        let stoneRadius = length / 20
        let stoneSize = CGSize(width: length/10, height: length/10)
        var all: [StoneNode] = []
        for field in game.fields {
            all.append(StoneNode.init(field: field, size: stoneSize))
        }
        self.fieldNodes = all
        
        let center: CGPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let lineWidth = stoneRadius / 5
        
        let outterRingNode = SKShapeNode(rectOf: CGSize(width: length - stoneRadius, height: length - stoneRadius))
        let middleRingNode = SKShapeNode(rectOf: CGSize(width: length - stoneRadius * 4, height: length - stoneRadius * 4))
        let innerRingNode = SKShapeNode(rectOf: CGSize(width: length - stoneRadius * 7, height: length - stoneRadius * 7))
        
        let lineLength = stoneRadius * 6
        let upLine = SKShapeNode(rectOf: CGSize(width: lineWidth, height: lineLength))
        let rightLine = SKShapeNode(rectOf: CGSize(width: lineLength, height: lineWidth))
        let downLine = SKShapeNode(rectOf: CGSize(width: lineWidth, height: lineLength))
        let leftLine = SKShapeNode(rectOf: CGSize(width: lineLength, height: lineWidth))
        
        self.outlineNodes = [outterRingNode,middleRingNode,innerRingNode,upLine,rightLine,downLine,leftLine]
        
        super.init(size: size)
        
        self.backgroundColor = .white
        
        for ringNode in [outterRingNode,middleRingNode,innerRingNode] {
            ringNode.lineWidth = lineWidth
            ringNode.strokeColor = .black
            ringNode.fillColor = .clear
            ringNode.isUserInteractionEnabled = false
            self.addChild(ringNode)
            ringNode.position = center
        }
        for lineNode in [upLine,rightLine,downLine,leftLine] {
            lineNode.strokeColor = .black
            lineNode.fillColor = .black
            self.addChild(lineNode)
        }
        
        upLine.position = CGPoint(x: center.x, y: stoneRadius * 4)
        rightLine.position = CGPoint(x: stoneRadius * 16, y: center.y)
        downLine.position = CGPoint(x: center.x, y: stoneRadius * 16)
        leftLine.position = CGPoint(x: stoneRadius * 4, y: center.y)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
