//
//  GameViewController.swift
//  MuehleGame
//
//  Created by Sven Deichsel on 25.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    @IBOutlet weak var Label: UILabel!
    @IBOutlet weak var gameView: SKView!
    
    @IBOutlet weak var WhiteButton: UIButton!
    @IBOutlet weak var BlackButton: UIButton!
    
    var game: Game!
    weak var scene: MuehleScene?
    
    let gameQueue: DispatchQueue = DispatchQueue.global(qos: .userInteractive)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.game = Game(whiteType: SmartPlayer.self, blackType: SmartPlayer.self)
        
        let length = min(self.gameView.frame.width, self.gameView.frame.height)
        let centerSquare = CGRect(x: (self.gameView.frame.width - length) / 2, y: (self.gameView.frame.height - length) / 2, width: length, height: length)
        
        let scene = MuehleScene(game: self.game, size: centerSquare.size)
        
        scene.informUserDelegate = self
        
        scene.scaleMode = .aspectFit
        self.gameView.presentScene(scene)
        
        self.gameView.ignoresSiblingOrder = true
        
        self.scene = scene
        /*
        self.gameView.showsFPS = true
        self.gameView.showsNodeCount = true
        */
        
        self.WhiteButton.addTarget(self, action: #selector(GameViewController.didSelectWhite), for: .touchUpInside)
        self.BlackButton.addTarget(self, action: #selector(GameViewController.didSelectBlack), for: .touchUpInside)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @objc func didSelectWhite() {
        self.gameQueue.async {
            guard let scene = self.scene else { return }
            self.game.changePlayer(for: .white, to: scene)
            self.game.changePlayer(for: .black, to: SmartPlayer(color: .black))
            
            DispatchQueue.main.async {
                self.disableButtons()
            }
        }
        gameQueue.async {
            self.game.resetBoard()
            self.game.play()
        }
    }
    @objc func didSelectBlack() {
        self.gameQueue.async {
            guard let scene = self.scene else { return }
            self.game.changePlayer(for: .black, to: scene)
            self.game.changePlayer(for: .white, to: SmartPlayer(color: .white))
            
            DispatchQueue.main.async {
                self.disableButtons()
            }
        }
        gameQueue.async {
            self.game.play()
        }
    }
    
    func disableButtons() {
        self.WhiteButton.isEnabled = false
        self.BlackButton.isEnabled = false
    }
    func enableButtons() {
        self.WhiteButton.isEnabled = true
        self.BlackButton.isEnabled = true
    }
    
    override var shouldAutorotate: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension GameViewController: InformUserDelegate {
    func new(moves: Game.PossibleMove, for color: Game.Color) {
        switch moves {
        case .move(_):
            DispatchQueue.main.async {
                self.Label.text = "Move a stone"
            }
        case .place(inEither: _):
            DispatchQueue.main.async {
                self.Label.text = "Place a stone (Left: \(self.game.numberOfLeftStones(for: color)))"
            }
        case .remove(either: _):
            DispatchQueue.main.async {
                self.Label.text = "Remove a stone"
            }
        case .noMove:
            DispatchQueue.main.async {
                self.Label.text = "No moves available"
            }
        }
    }
    func moveEnded() {
        DispatchQueue.main.async {
            self.Label.text = "Mühle"
        }
    }
    func gameWon() {
        DispatchQueue.main.async {
            self.Label.text = "You won!"
            self.enableButtons()
        }
    }
    func gameLost() {
        DispatchQueue.main.async {
            self.Label.text = "You lost!"
            self.enableButtons()
        }
    }
    func gameDraw() {
        DispatchQueue.main.async {
            self.Label.text = "Game was a draw."
            self.enableButtons()
        }
    }
}
