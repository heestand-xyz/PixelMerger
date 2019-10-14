//
//  PixelMerger.swift
//  PixelMerger
//
//  Created by Anton Heestand on 2019-10-14.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import Foundation
import PixelKit

public class PixelMerger {
    
    // MARK: - Merge
    
    public enum MergeError: Error {
        case urlNotFound
        case noUrls
    }
    
    public static func merge(videos: [String], done: @escaping (URL) -> (), failed: @escaping (Error) -> ()) {
        let urls = videos.compactMap({ video in self.getUrl(from: video) })
        guard urls.count == videos.count else { failed(MergeError.urlNotFound); return }
        merge(urls: urls, done: done, failed: failed)
    }
    
    public static func merge(urls: [URL], done: @escaping (URL) -> (), failed: @escaping (Error) -> ()) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("PixelMerger").appendingPathComponent("merged-video-\(UUID().uuidString).mov")
        merge(urls: urls, to: url, done: {
            done(url)
        }, failed: failed)
    }
    
    public static func merge(videos: [String], to url: URL, done: @escaping () -> (), failed: @escaping (Error) -> ()) {
        let urls = videos.compactMap({ video in self.getUrl(from: video) })
        guard urls.count == videos.count else { failed(MergeError.urlNotFound); return }
        merge(urls: urls, to: url, done: done, failed: failed)
    }
    
    public static func merge(urls: [URL], to url: URL, done: @escaping () -> (), failed: @escaping (Error) -> ()) {
        print("PixelMerger - Merge")
        PixelKit.main.render.engine.renderMode = .manual
        
        guard !urls.isEmpty else { failed(MergeError.noUrls); return }
        var urls = urls
        
        let videoPix = VideoPIX()
        videoPix.name = "pixelmerger-video"
        
        func finalVideoDone() {
            print("PixelMerger - Final Video Done")
            done()
        }
        
        func nextVideo(url: URL) {
            print("PixelMerger - Next Video:", url.lastPathComponent)
            videoPix.load(url: url, done: {
                
                let frameCount = videoPix.frameCount.val
                
                func finalFrameDone() {
                    print("PixelMerger - Final Frame Done")
                    if !urls.isEmpty {
                        nextVideo(url: urls.remove(at: 0))
                    } else {
                        finalVideoDone()
                    }
                }
                
                func nextFrame(index: Int) {
                    print("PixelMerger - Next Frame:", index)
                    do {
                        try PixelKit.main.render.engine.manuallyRender({
                            
                            print("PixelMerger - Manual Render Done:", index)

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
        }
        nextVideo(url: urls.remove(at: 0))
        
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
