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
import UIKit
import AVFoundation
import AVKit
import AssetsLibrary

public class PixelMerger {
    
    // MARK: - Merge
    
    public enum MergeError: Error {
        case urlNotFound
        case noUrls
        case badMetaData(String)
    }
    
    public struct Progress {
        public let videoIndex: Int
        public let videoFraction: CGFloat
        public let totalFraction: CGFloat
    }
    
    public struct VideoMetaData: Codable {
        public let name: String
        public let fps: Int
        public let frames: Int
        public let duration: Double
        public let resolution: CGSize
    }
    
    public struct VideoWithAudio {
        public let url: URL
        public let time: Double
        public let duration: Double
        public init(url: URL, time: Double, duration: Double) {
            self.url = url
            self.time = time
            self.duration = duration
        }
    }
    
    public static func merge(videos: [String], at resolution: Resolution, fps: Int, progress: @escaping (Progress) -> (), done: @escaping (URL) -> (), failed: @escaping (Error) -> ()) {
        let urls = videos.compactMap({ video in self.getUrl(from: video) })
        guard urls.count == videos.count else { failed(MergeError.urlNotFound); return }
        merge(urls: urls, at: resolution, fps: fps, progress: progress, done: done, failed: failed)
    }
    
    public static func merge(urls: [URL], at resolution: Resolution, fps: Int, progress: @escaping (Progress) -> (), done: @escaping (URL) -> (), failed: @escaping (Error) -> ()) {
        
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
        
        var allVideoMetaData: [VideoMetaData] = []
        func getTotalFrameCount() -> Int {
            var frameCount = 0
            for videoMetaData in allVideoMetaData {
                frameCount += videoMetaData.frames
            }
            return frameCount
        }
        func getFrameCount(to index: Int) -> Int {
            var frameCount = 0
            for i in 0..<index {
                frameCount += allVideoMetaData[i].frames
            }
            return frameCount
        }
        
        func finalVideoDone() {
            print("PixelMerger - Final Video Done")
            colorPix.destroy()
            videoPix.destroy()
            recordPix.stopRec({ url in
                print("PixelMerger - Record Stopped")
                done(url)
                recordPix.destroy()
            }) { error in
                failed(error)
                recordPix.destroy()
            }
        }
        
        var videoIndex = 0
        func nextVideo(url: URL) {
            print("")
            print("")
            print("PixelMerger - Next Video:", url.lastPathComponent)
            videoPix.load(url: url, done: { _ in
                
                print("PixelMerger - Video Loaded")

                let frameCount = allVideoMetaData[videoIndex].frames
                let prevFrameCount = getFrameCount(to: videoIndex)
                
                videoPix.nextFrame(done: {
                
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
                        let videoFraction = CGFloat(index) / CGFloat(frameCount)
                        let totalFraction = CGFloat(prevFrameCount + index) / CGFloat(getTotalFrameCount())
                        progress(Progress(videoIndex: videoIndex, videoFraction: videoFraction, totalFraction: totalFraction))
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
        
        func videoMetaDataDone() {
            do {
                try recordPix.startRec()
                print("PixelMerger - Record Started")
                nextVideo(url: urls.remove(at: 0))
            } catch {
                failed(error)
            }
        }
        
        var metaDataUrls = urls
        func nextVideoMetaData(url: URL) {
            videoMetaData(url: url, done: { videoMetaData in
                allVideoMetaData.append(videoMetaData)
                if metaDataUrls.isEmpty {
                    videoMetaDataDone()
                } else {
                    nextVideoMetaData(url: metaDataUrls.remove(at: 0))
                }
            }) { error in
                failed(error)
            }
        }
        nextVideoMetaData(url: metaDataUrls.remove(at: 0))
        
        
    }
    
    public static func videoMetaData(video: String, done: @escaping (VideoMetaData) -> (), failed: @escaping (Error) -> ()) {
        guard let url = self.getUrl(from: video) else { failed(MergeError.urlNotFound); return }
        videoMetaData(url: url, done: done, failed: failed)
    }
    
    public static func videoMetaData(url: URL, done: @escaping (VideoMetaData) -> (), failed: @escaping (Error) -> ()) {
        
        let videoPix = VideoPIX()
        videoPix.name = "pixelmerger-video-meta-data"
        
        videoPix.load(url: url, done: { resolution in

            let name = url.lastPathComponent
            
            guard let fps = videoPix.fps else {
                failed(MergeError.badMetaData("fps"))
                videoPix.destroy()
                return
            }
            guard let duration = videoPix.duration else {
                failed(MergeError.badMetaData("duration"))
                videoPix.destroy()
                return
            }
            guard let frames = videoPix.frameCount else {
                failed(MergeError.badMetaData("frameCount"))
                videoPix.destroy()
                return
            }

            let videoMetaData = VideoMetaData(name: name, fps: fps, frames: frames, duration: duration, resolution: resolution.size.cg)
            
            done(videoMetaData)
            videoPix.destroy()
            
        })
        
    }
    
    // MARK: - Video & Audio Merge
    
    /// https://stackoverflow.com/questions/31984474/swift-merge-audio-and-video-files-into-one-video
    
    public static func mergeVideoWithAudio(name: String, videoUrl: URL, audioUrl: URL, success: @escaping ((URL) -> Void), failure: @escaping ((Error?) -> Void)) {
        
        print("PixelMerger - Merge Video With Audio:", name)
        
        let mixComposition: AVMutableComposition = AVMutableComposition()
        var mutableCompositionVideoTrack: [AVMutableCompositionTrack] = []
        var mutableCompositionAudioTrack: [AVMutableCompositionTrack] = []
        let totalVideoCompositionInstruction : AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        
        let aVideoAsset: AVAsset = AVAsset(url: videoUrl)
        let aAudioAsset: AVAsset = AVAsset(url: audioUrl)
        
        if let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
           let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            mutableCompositionVideoTrack.append(videoTrack)
            mutableCompositionAudioTrack.append(audioTrack)
            
            if let aVideoAssetTrack: AVAssetTrack = aVideoAsset.tracks(withMediaType: .video).first,
               let aAudioAssetTrack: AVAssetTrack = aAudioAsset.tracks(withMediaType: .audio).first {
                do {
                    try mutableCompositionVideoTrack.first?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aVideoAssetTrack, at: CMTime.zero)
                    try mutableCompositionAudioTrack.first?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aAudioAssetTrack, at: CMTime.zero)
                    videoTrack.preferredTransform = aVideoAssetTrack.preferredTransform
                    
                } catch{
                    print(error)
                }
                
                
                totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration)
            }
        }
        
        PixelMerger.export(name: name, with: mixComposition, success: success, failure: failure)
        
    }
    
    public static func mergeMix(name: String, videoUrl: URL, audioUrl: URL, videosWithAudio: [VideoWithAudio], success: @escaping ((URL) -> Void), failure: @escaping ((Error?) -> Void)) {
        
        print("PixelMerger - Merge Video With Audio:", name)
        
        let mixComposition: AVMutableComposition = AVMutableComposition()
        var mutableCompositionVideoTrack: AVMutableCompositionTrack!
        var mutableCompositionAudioTrack: AVMutableCompositionTrack!
        var mutableCompositionAudioTracks: [AVMutableCompositionTrack]!
        let totalVideoCompositionInstruction : AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        
        let aVideoAsset: AVAsset = AVAsset(url: videoUrl)
        let aAudioAsset: AVAsset = AVAsset(url: audioUrl)
        let aVideoWithAudioAssets: [AVAsset] = videosWithAudio.map({ AVAsset(url: $0.url) })
        
        if let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let audioTracks = [AVMutableCompositionTrack].init(repeating: mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!, count: videosWithAudio.count)
            
            mutableCompositionVideoTrack = videoTrack
            mutableCompositionAudioTrack = audioTrack
            mutableCompositionAudioTracks = audioTracks
            
            if let aVideoAssetTrack: AVAssetTrack = aVideoAsset.tracks(withMediaType: .video).first,
               let aAudioAssetTrack: AVAssetTrack = aAudioAsset.tracks(withMediaType: .audio).first {
                let aVideoWithAudioAssetTracks: [AVAssetTrack] = aVideoWithAudioAssets.compactMap({ $0.tracks(withMediaType: .audio).first })
                 do {
                    try mutableCompositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aVideoAssetTrack, at: CMTime.zero)
                    try mutableCompositionAudioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aAudioAssetTrack, at: CMTime.zero)
                    try zip(videosWithAudio, zip(mutableCompositionAudioTracks, aVideoWithAudioAssetTracks)).forEach { arg in
                        let (meta, (compAndTrack)) = arg
                        let (comp, track) = compAndTrack
                        try comp.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: track.timeRange.duration), of: track, at: CMTime(seconds: meta.time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }
                    videoTrack.preferredTransform = aVideoAssetTrack.preferredTransform
                    
                } catch{
                    print(error)
                }
                
                
                totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration)
            }
        }
        
        PixelMerger.export(name: name, with: mixComposition, success: success, failure: failure)
        
    }
    
    static func export(name: String, with mixComposition: AVMutableComposition, success: @escaping ((URL) -> Void), failure: @escaping ((Error?) -> Void)) {
        
        print("PixelMerger - Export:", name)
        
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let outputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("\(name).m4v")
            
            do {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    
                    try FileManager.default.removeItem(at: outputURL)
                }
            } catch { }
            
            if let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) {
                exportSession.outputURL = outputURL
                exportSession.outputFileType = AVFileType.mp4
                exportSession.shouldOptimizeForNetworkUse = true
                
                exportSession.exportAsynchronously(completionHandler: {
                    switch exportSession.status {
                    case .failed:
                        if let _error = exportSession.error {
                            DispatchQueue.main.async {
                                failure(_error)
                            }
                        }
                        
                    case .cancelled:
                        if let _error = exportSession.error {
                            DispatchQueue.main.async {
                                failure(_error)
                            }
                        }
                        
                    default:
                        print("PixelMerger - Export:", name, "Done!")
                        DispatchQueue.main.async {
                            success(outputURL)
                        }
                    }
                })
            } else {
                failure(nil)
            }
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
