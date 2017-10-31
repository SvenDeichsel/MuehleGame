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
    
    @IBOutlet weak var OpponentLabel: UILabel!
    @IBOutlet weak var OpponentSegment: UISegmentedControl!
    
    @IBOutlet weak var NewGameButton: UIButton!
    
    var game: Game!
    var playingColor: Game.Color = .white
    
    weak var scene: MuehleScene?
    
    /// The queue on which the game is played
    let gameQueue: DispatchQueue = {() -> DispatchQueue in
        // Muss ein serial Queue sein
        let queue = DispatchQueue.init(label: "GameQueue", qos: DispatchQoS.userInteractive, attributes: [])
        
        return queue
    }()

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
        self.NewGameButton.addTarget(self, action: #selector(GameViewController.newGame), for: .touchUpInside)
        
        self.NewGameButton.isEnabled = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let data = UserDefaults.standard.data(forKey: "Game") {
            do {
                let old = try Game.unarchived(from: data, with: {
                    self.scene?.playingColor = $0
                    self.playingColor = $0
                    return self.scene!
                })
                self.game = old.game
                old.game.delegate = self.scene
                
                self.disableButtons()
                self.gameQueue.async {
                    for field in old.game.fields {
                        self.scene?.needsRefresh(at: field)
                    }
                    self.game.play(start: old.phase)
                }
            } catch {
                print(error)
            }
        }
    }
    
    @objc func didSelectWhite() {
        self.gameQueue.async {
            guard let scene = self.scene else { return }
            self.game.changePlayer(for: .white, to: scene)
            self.playingColor = .white
            scene.playingColor = .white
            self.game.changePlayer(for: .black, to: self.createOpponent(for: .black))
            
            DispatchQueue.main.async {
                self.disableButtons()
            }
        }
        self.gameQueue.async {
            self.game.resetBoard()
            self.game.play()
        }
    }
    @objc func didSelectBlack() {
        self.gameQueue.async {
            guard let scene = self.scene else { return }
            self.game.changePlayer(for: .black, to: scene)
            self.playingColor = .black
            scene.playingColor = .black
            self.game.changePlayer(for: .white, to: self.createOpponent(for: .white))
            
            DispatchQueue.main.async {
                self.disableButtons()
            }
        }
        self.gameQueue.async {
            self.game.resetBoard()
            self.game.play()
        }
    }
    @objc func newGame() {
        self.scene?.endGame = true
    }
    
    func createOpponent(for color: Game.Color) -> Player {
        return DispatchQueue.main.sync {() -> Player in
            switch self.OpponentSegment.selectedSegmentIndex {
            case 0:
                return RandomPlayer(color: color)
            case 1:
                return SmartPlayer(color: color, numLevels: 4)
            default:
                return SmartPlayer(color: color, numLevels: 6)
            }
        }
    }
    
    func disableButtons() {
        switch self.playingColor {
        case .white:
            self.WhiteButton.isUserInteractionEnabled = false
            self.BlackButton.isEnabled = false
        case .black:
            self.WhiteButton.isEnabled = false
            self.BlackButton.isUserInteractionEnabled = false
        }
        
        self.OpponentSegment.isEnabled = false
        self.NewGameButton.isEnabled = true
    }
    func enableButtons() {
        self.WhiteButton.isEnabled = true
        self.WhiteButton.isUserInteractionEnabled = true
        self.BlackButton.isEnabled = true
        self.BlackButton.isUserInteractionEnabled = true
        
        self.OpponentSegment.isEnabled = true
        self.NewGameButton.isEnabled = false
        
        self.deleteGame()
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
    func new(moves: Game.PossibleMove) {
        switch moves {
        case .move(_):
            DispatchQueue.main.async {
                self.Label.text = "Move a stone"
            }
        case .place(inEither: _, left: let num):
            DispatchQueue.main.async {
                self.Label.text = "Place a stone (Left: \(num))"
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
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try self.game.archived()
                
                UserDefaults.standard.set(data, forKey: "Game")
            } catch {
                print(error)
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
    func deleteGame() {
        UserDefaults.standard.removeObject(forKey: "Game")
    }
}
