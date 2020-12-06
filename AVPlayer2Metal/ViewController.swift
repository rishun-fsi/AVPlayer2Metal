//
//  ViewController.swift
//  AVPlayer2Metal
//
//  Created by lisyunn on 2020/12/05.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    let player: AVPlayer = AVPlayer()
    
    @IBOutlet weak var metalView: MetalView!
    
    @IBOutlet weak var metalView2: MetalView!
    lazy var playerItemVideoOutput: AVPlayerItemVideoOutput = {
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    
    lazy var displayLink: CADisplayLink = {
        let dl = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        dl.add(to: .current, forMode: .default)
        dl.isPaused = true
        return dl
    }()


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // Get the video file url.
        guard let  url = URL(string:"https://bitmovin-a.akamaihd.net/content/art-of-motion_drm/m3u8s/11331.m3u8") else {
            print("Impossible to find the video.")
            return
        }
         
        // Create an av asset for the given url.
        let asset = AVURLAsset(url: url)
         
        // Create a av player item from the asset.
        let playerItem = AVPlayerItem(asset: asset)
         
        // Add the player item video output to the player item.
        playerItem.add(playerItemVideoOutput)
         
        // Add the player item to the player.
        player.replaceCurrentItem(with: playerItem)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
     
        // Resume the display link
        displayLink.isPaused = false
     
        // Start to play
        player.play()
    }
     

    @objc private func readBuffer(_ sender: CADisplayLink) {
     
        var currentTime = CMTime.invalid
        let nextVSync = sender.timestamp + sender.duration
        currentTime = playerItemVideoOutput.itemTime(forHostTime: nextVSync)
     
        if playerItemVideoOutput.hasNewPixelBuffer(forItemTime: currentTime), let pixelBuffer = playerItemVideoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
            self.metalView.pixelBuffer = pixelBuffer
            self.metalView2.pixelBuffer = pixelBuffer
        }
    }
    

}

