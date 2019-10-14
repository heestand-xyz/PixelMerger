//
//  PixelMerger.swift
//  PixelMerger
//
//  Created by Anton Heestand on 2019-10-14.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import Foundation

public class PixelMerger {
    
    // MARK: - Merge
    
    public enum MergeError: Error {
        case urlNotFound
    }
    
    public static func merge(videos: [String], done: @escaping (URL) -> ()) throws {
        let urls = videos.compactMap({ video in self.getUrl(from: video) })
        guard urls.count == videos.count else { throw MergeError.urlNotFound }
        try merge(urls: urls, done: done)
    }
    
    public static func merge(urls: [URL], done: @escaping (URL) -> ()) throws {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try merge(urls: urls, to: url, done: {
            done(url)
        })
    }
    
    public static func merge(videos: [String], to url: URL, done: @escaping () -> ()) throws {
        let urls = videos.compactMap({ video in self.getUrl(from: video) })
        guard urls.count == videos.count else { throw MergeError.urlNotFound }
        try merge(urls: urls, to: url, done: done)
    }
    
    public static func merge(urls: [URL], to url: URL, done: @escaping () -> ()) throws {
        
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
