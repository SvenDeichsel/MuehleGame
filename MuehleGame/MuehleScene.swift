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
    /// Das Mühlespiel, welches gespielt wird
    let game: Game
    
    /// Die Felder
    var fieldNodes: [StoneNode]
    
    /// Die Spielfeldlinien
    var outlineNodes: [SKShapeNode]
    
    /// Der Radius für die Spielsteine
    var stoneRadius: CGFloat
    /// Das Centrum des Spielfeldes
    var center: CGPoint
    /// Die Linienbreite
    var lineWidth: CGFloat
    
    /// Der Spielstein, der vom Spieler bewegt wird
    var movingNode: StoneNode? = nil
    /// Der Ursprungsspielstein, von dem ein Stein bewegt wurde
    var fromNode: StoneNode? = nil
    
    weak var informUserDelegate: InformUserDelegate?
    
    // Mit den folgenden Variablen wird das Spielen ermöglicht
    var playingColor: Game.Color? = nil
    var possibleMoves: Game.PossibleMove? = nil
    var chosenMove: Game.Move? = nil
    // Signalisiert, dass der Nutzer das Spiel nicht mehr weiter spielen will
    var endGame: Bool = false {
        didSet {
            if endGame {
                self.choosingSemaphore.signal()
            }
        }
    }
    let choosingSemaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    
    override convenience init(size: CGSize) {
        let game = Game(whiteType: RandomPlayer.self, blackType: RandomPlayer.self)
        self.init(game: game, size: size)
    }
    
    init(game: Game, size: CGSize) {
        self.game = game
        
        // Spiel setup
        let length = min(size.width, size.height) - 16.0
        let stoneRadius = length / 20
        self.stoneRadius = stoneRadius
        let stoneSize = CGSize(width: length/10, height: length/10)
        var all: [StoneNode] = []
        for field in game.fields {
            all.append(StoneNode(field: field, size: stoneSize))
        }
        self.fieldNodes = all
        
        let center: CGPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        self.center = center
        let lineWidth = stoneRadius / 5
        self.lineWidth = lineWidth
        
        let outterRingNode = SKShapeNode(rectOf: CGSize(width: length - stoneRadius * 2, height: length - stoneRadius * 2))
        let middleRingNode = SKShapeNode(rectOf: CGSize(width: length - stoneRadius * 8, height: length - stoneRadius * 8))
        let innerRingNode = SKShapeNode(rectOf: CGSize(width: length - stoneRadius * 14, height: length - stoneRadius * 14))
        
        let lineLength = stoneRadius * 6
        let upLine = SKShapeNode(rectOf: CGSize(width: lineWidth, height: lineLength))
        let rightLine = SKShapeNode(rectOf: CGSize(width: lineLength, height: lineWidth))
        let downLine = SKShapeNode(rectOf: CGSize(width: lineWidth, height: lineLength))
        let leftLine = SKShapeNode(rectOf: CGSize(width: lineLength, height: lineWidth))
        
        self.outlineNodes = [outterRingNode,middleRingNode,innerRingNode,upLine,rightLine,downLine,leftLine]
        
        super.init(size: size)
        
        self.game.delegate = self
        self.backgroundColor = UIColor.lightGray
        
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
            lineNode.lineWidth = 0.0
            lineNode.fillColor = .black
            self.addChild(lineNode)
        }
        
        upLine.position = CGPoint(x: center.x, y: stoneRadius * 4 + 8.0)
        rightLine.position = CGPoint(x: stoneRadius * 16 + 8.0, y: center.y)
        downLine.position = CGPoint(x: center.x, y: stoneRadius * 16 + 8.0)
        leftLine.position = CGPoint(x: stoneRadius * 4 + 8.0, y: center.y)
        
        for node in self.fieldNodes {
            node.name = "Field Node"
            self.addChild(node)
            node.position = self.position(for: node.field)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Ermöglicht das bewegen, setzen und entfernen von Spielsteinen
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let possible = possibleMoves, let touch = touches.first else {
            return
        }
        let loc = touch.location(in: self)
        let nodes = self.nodes(at: loc).filter({ return $0.name == "Field Node" })
        guard let node = nodes.first as? StoneNode, nodes.count == 1 else {
            return
        }
        guard possible.contains(from: Game.MuehleField(field: node.field)) else {
            return
        }
        self.fromNode = node
        
        if case Game.PossibleMove.move(_) = possible {
            node.fillColor = .clear
            
            self.createMovingNode(at: loc, with: node.field)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let node = self.movingNode, let touch = touches.first else {
            return
        }
        node.position = touch.location(in: self).offset(dx: -self.stoneRadius, dy: -self.stoneRadius)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard let possible = possibleMoves, let touch = touches.first else {
            self.undoMoving()
            return
        }
        let loc = touch.location(in: self)
        let nodes = self.nodes(at: loc).filter({ return $0.name == "Field Node" })
        guard let from = self.fromNode, let to = nodes.first as? StoneNode, nodes.count == 1 else {
            self.undoMoving()
            return
        }
        guard let move = possible.getMove(from: Game.MuehleField(field: from.field), to: Game.MuehleField(field: to.field)) else {
            self.undoMoving()
            return
        }
        self.chosenMove = move
        
        self.removeMovingNode()
        
        self.choosingSemaphore.signal()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        self.undoMoving()
    }
    
    /// Erstellt einen Stein, der vom Nutzer bewegt werden kann
    @discardableResult
    func createMovingNode(at point: CGPoint, with: Field) -> StoneNode {
        let node = StoneNode(field: with, size: CGSize(width: 2 * self.stoneRadius, height: 2 * self.stoneRadius))
        if self.movingNode != nil {
            self.removeMovingNode()
        }
        self.movingNode = node
        self.addChild(node)
        node.position = point
        
        return node
    }
    
    /// Macht das bewegen von Steinen durhc den Nutzer rückgängig
    func undoMoving() {
        if let n = self.fromNode {
            n.fillColor = n.field.color
        }
        removeMovingNode()
    }
    /// Enfernt den vom Nutzer bewegbaren Stein
    func removeMovingNode() {
        guard let node = self.movingNode else {
            return
        }
        node.removeFromParent()
        self.movingNode = nil
    }
    
    /// Gibt die Position eines Steines im Spielfeld zurück
    func position(for field: Field) -> CGPoint {
        let row = CGFloat(6-field.row)
        let column = CGFloat(field.column)
        
        return CGPoint(x: column * self.stoneRadius * 3 + 8.0, y: row * self.stoneRadius * 3 + 8.0)
    }
    
    /// Bewegt einen Stein in dem zurückgegebenen Zeitintervall
    func moveStone(from: Field, to: Field) -> TimeInterval {
        guard from != to else {
            return 0.0
        }
        guard let fromNode = self.node(for: from), let toNode = self.node(for: to) else {
                return 0.0
        }
        let distance = fromNode.position.distance(to: toNode.position)
        let duration = TimeInterval(distance / self.frame.width * 2)
        
        let moveAction = SKAction.move(to: toNode.position, duration: duration)
        
        let moving = StoneNode(field: from, size: fromNode.frame.size)
        moving.fillColor = fromNode.fillColor
        self.addChild(moving)
        self.movingNode = moving
        
        moving.position = fromNode.position
        moving.run(moveAction) {
            toNode.fillColor = to.color
            moving.removeFromParent()
            self.movingNode = nil
        }
        fromNode.fillColor = .clear
        return duration
    }
    /// Aktualisiert den Stein
    func refreshStone(at: Field) -> TimeInterval {
        guard let node = self.node(for: at) else {
            return 0.0
        }
        node.fillColor = at.color
        return 0.0
    }
    /// Gibt den graphischen Spielstein für einen Spielstein zurück
    func node(for field: Field) -> StoneNode? {
        return self.fieldNodes[field.id]
        //return self.fieldNodes.first(where: { return $0.field == field })
    }
}

// Aktualisiert das Spielbrett für die Computergesteuerten Züge
extension MuehleScene: GameDelegate {
    func moved(from: Field, to: Field) {
        DispatchQueue.main.async {
            self.node(for: from)?.fillColor = from.color
            self.node(for: to)?.fillColor = to.color
        }
    }
    func needsRefresh(at: Field) {
        DispatchQueue.main.async {
            self.node(for: at)?.fillColor = at.color
        }
    }
    func move(from: Field, to: Field) -> TimeInterval {
        return DispatchQueue.main.sync {
            return self.moveStone(from: from, to: to)
        }
    }
    func refresh(at: Field) -> TimeInterval {
        return DispatchQueue.main.sync {
            return self.refreshStone(at: at)
        }
    }
}

/*
 Sorgt dafür, dass der Nutzer, mit der graphischen Oberfläche spielen kann.
 
 Da die Anfragen des Spiels nicht auf dem main-thread ausgeführt werden, kann dieser blockiert werden, bis der Nutzer seine Auswahl getroffen hat.
 */
extension MuehleScene: Player {
    func chooseMove(from possible: Game.PossibleMove, phase: Game.Phase, previous: Game.Phase?, in game: Game) -> Game.Move? {
        self.informUserDelegate?.new(moves: possible)
        self.possibleMoves = possible
        
        var move: Game.Move?
        while move == nil {
            self.choosingSemaphore.wait()
            if self.endGame {
                self.endGame = false
                self.possibleMoves = nil
                self.chosenMove = nil
                return nil
            }
            move = self.chosenMove
            self.chosenMove = nil
        }
        
        self.possibleMoves = nil
        
        if self.endGame {
            self.endGame = false
            return nil
        }
        
        self.informUserDelegate?.moveEnded()
        
        return move
    }
    
    func won(game: Game) {
        print("Won :)")
        self.informUserDelegate?.gameWon()
    }
    
    func lost(game: Game) {
        print("Lost :(")
        self.informUserDelegate?.gameLost()
    }
    
    func draw(game: Game) {
        print("Draw")
        self.informUserDelegate?.gameDraw()
    }
}

// Gibt Spielphasen an den Nutzer weiter
protocol InformUserDelegate: class {
    func new(moves: Game.PossibleMove)
    func moveEnded()
    
    func gameWon()
    func gameLost()
    func gameDraw()
}
