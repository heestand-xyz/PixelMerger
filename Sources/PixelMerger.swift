//
//  PixelMerger.swift
//  PixelMerger
//
//  Created by Anton Heestand on 2019-10-14.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import Foundation
import RenderKit
import PixelKit

public class PixelMerger {
    
    // MARK: - Merge
    
    public enum MergeError: Error {
        case urlNotFound
        case noUrls
    }
    
    public static func merge(videos: [String], at resolution: Resolution, fps: Int, progress: @escaping (Int, CGFloat) -> (), done: @escaping (URL) -> (), failed: @escaping (Error) -> ()) {
        let urls = videos.compactMap({ video in self.getUrl(from: video) })
        guard urls.count == videos.count else { failed(MergeError.urlNotFound); return }
        merge(urls: urls, at: resolution, fps: fps, progress: progress, done: done, failed: failed)
    }
    
    public static func merge(urls: [URL], at resolution: Resolution, fps: Int, progress: @escaping (Int, CGFloat) -> (), done: @escaping (URL) -> (), failed: @escaping (Error) -> ()) {
        
        print("")
        print("")
        print("")
        print("PixelMerger - Merge")
        PixelKit.main.render.engine.renderMode = .manual
        
        guard !urls.isEmpty else { failed(MergeError.noUrls); return }
        var urls = urls
        
        let colorPix = ColorPIX(at: resolution)
        colorPix.color = .black
        
        let videoPix = VideoPIX()
        videoPix.name = "pixelmerger-video"
        
        let recordPix = RecordPIX()
        recordPix.name = "pixelmerger-record"
        recordPix.input = colorPix & videoPix
        
        recordPix.realtime = false
        recordPix.timeSync = false
        recordPix.fps = fps
        recordPix.directMode = false
        
        func finalVideoDone() {
            print("PixelMerger - Final Video Done")
            recordPix.stopRec({ url in
                print("PixelMerger - Record Stopped")
                done(url)
            }) { error in
                failed(error)
            }
        }
        
        var videoIndex = 0
        func nextVideo(url: URL) {
            print("")
            print("")
            print("PixelMerger - Next Video:", url.lastPathComponent)
            videoPix.load(url: url, done: {
                
                print("PixelMerger - Video Loaded")
                
                videoPix.nextFrame(done: {
                
                    let frameCount = videoPix.frameCount.val
                    
                    func finalFrameDone() {
                        print("PixelMerger - Final Frame Done")
                        if !urls.isEmpty {
                            videoIndex += 1
                            nextVideo(url: urls.remove(at: 0))
                        } else {
                            finalVideoDone()
                        }
                    }
                    
                    func nextFrame(index: Int) {
                        progress(videoIndex, CGFloat(index) / CGFloat(frameCount))
                        print("PixelMerger - Next Frame:", index)
                        do {
                            try PixelKit.main.render.engine.manuallyRender({
                                
                                print("PixelMerger - Manual Render Done:", index)
                                print("")

                                if index < frameCount - 1 {
                                    let nextIndex = index + 1
                                    videoPix.seekFrame(to: nextIndex, done: {
                                        
                                        print("PixelMerger - Seek Done:", index)

                                        nextFrame(index:nextIndex)
                                                        
                                    })
                                } else {
                                   finalFrameDone()
                                }
                                
                            })
                        } catch {
                            failed(error)
                        }
                    }
                    nextFrame(index: 0)
                    
                    
                })
                
            })
        }
        
        do {
            try recordPix.startRec()
            print("PixelMerger - Record Started")
            nextVideo(url: urls.remove(at: 0))
        } catch {
            failed(error)
        }
        
    }
    
    // MARK: - URL from Name
    
    static func getUrl(from fullName: String) -> URL? {
        let parts = fullName.split(separator: ".")
        if parts.count >= 2 {
            let ext = String(parts.last!)
            let name = fullName.replacingOccurrences(of: ".\(ext)", with: "")
            return Bundle.main.url(forResource: name, withExtension: ext)
        } else {
            return Bundle.main.url(forResource: fullName, withExtension: nil)
        }
    }
    
}
