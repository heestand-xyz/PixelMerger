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
    
    public static func mergeVideoWithAudio(videoUrl: URL, audioUrl: URL, success: @escaping ((URL) -> Void), failure: @escaping ((Error?) -> Void)) {


        let mixComposition: AVMutableComposition = AVMutableComposition()
        var mutableCompositionVideoTrack: [AVMutableCompositionTrack] = []
        var mutableCompositionAudioTrack: [AVMutableCompositionTrack] = []
        let totalVideoCompositionInstruction : AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()

        let aVideoAsset: AVAsset = AVAsset(url: videoUrl)
        let aAudioAsset: AVAsset = AVAsset(url: audioUrl)

        if let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid), let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            mutableCompositionVideoTrack.append(videoTrack)
            mutableCompositionAudioTrack.append(audioTrack)

        if let aVideoAssetTrack: AVAssetTrack = aVideoAsset.tracks(withMediaType: .video).first, let aAudioAssetTrack: AVAssetTrack = aAudioAsset.tracks(withMediaType: .audio).first {
            do {
                try mutableCompositionVideoTrack.first?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aVideoAssetTrack, at: CMTime.zero)
                try mutableCompositionAudioTrack.first?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aAudioAssetTrack, at: CMTime.zero)
                   videoTrack.preferredTransform = aVideoAssetTrack.preferredTransform

            } catch{
                print(error)
            }


           totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero,duration: aVideoAssetTrack.timeRange.duration)
        }
        }

        let mutableVideoComposition: AVMutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mutableVideoComposition.renderSize = CGSize(width: 480, height: 640)

        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let outputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("\("fileName").m4v")

            do {
                if FileManager.default.fileExists(atPath: outputURL.path) {

                    try FileManager.default.removeItem(at: outputURL)
                }
            } catch { }

            if let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) {
                exportSession.outputURL = outputURL
                exportSession.outputFileType = AVFileType.mp4
                exportSession.shouldOptimizeForNetworkUse = true

                /// try to export the file and handle the status cases
                exportSession.exportAsynchronously(completionHandler: {
                    switch exportSession.status {
                    case .failed:
                        if let _error = exportSession.error {
                            failure(_error)
                        }

                    case .cancelled:
                        if let _error = exportSession.error {
                            failure(_error)
                        }

                    default:
                        print("finished")
                        success(outputURL)
                    }
                })
            } else {
                failure(nil)
            }
        }
    }
    
//    /// Merges video and sound while keeping sound of the video too
//    ///
//    /// - Parameters:
//    ///   - videoUrl: URL to video file
//    ///   - audioUrl: URL to audio file
//    ///   - shouldFlipHorizontally: pass True if video was recorded using frontal camera otherwise pass False
//    ///   - completion: completion of saving: error or url with final video
//    func mergeVideoAndAudio(videoUrl: URL,
//                            audioUrl: URL,
//                            shouldFlipHorizontally: Bool = false,
//                            completion: @escaping (_ error: Error?, _ url: URL?) -> Void) {
//
//        let mixComposition = AVMutableComposition()
//        var mutableCompositionVideoTrack = [AVMutableCompositionTrack]()
//        var mutableCompositionAudioTrack = [AVMutableCompositionTrack]()
//        var mutableCompositionAudioOfVideoTrack = [AVMutableCompositionTrack]()
//
//        //start merge
//
//        let aVideoAsset = AVAsset(url: videoUrl)
//        let aAudioAsset = AVAsset(url: audioUrl)
//
//        let compositionAddVideo = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
//                                                                       preferredTrackID: kCMPersistentTrackID_Invalid)
//
//        let compositionAddAudio = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio,
//                                                                     preferredTrackID: kCMPersistentTrackID_Invalid)
//
//        let compositionAddAudioOfVideo = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio,
//                                                                            preferredTrackID: kCMPersistentTrackID_Invalid)
//
//        let aVideoAssetTrack: AVAssetTrack = aVideoAsset.tracks(withMediaType: AVMediaTypeVideo)[0]
//        let aAudioOfVideoAssetTrack: AVAssetTrack? = aVideoAsset.tracks(withMediaType: AVMediaTypeAudio).first
//        let aAudioAssetTrack: AVAssetTrack = aAudioAsset.tracks(withMediaType: AVMediaTypeAudio)[0]
//
//        // Default must have tranformation
//        compositionAddVideo.preferredTransform = aVideoAssetTrack.preferredTransform
//
//        if shouldFlipHorizontally {
//            // Flip video horizontally
//            var frontalTransform: CGAffineTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)
//            frontalTransform = frontalTransform.translatedBy(x: -aVideoAssetTrack.naturalSize.width, y: 0.0)
//            frontalTransform = frontalTransform.translatedBy(x: 0.0, y: -aVideoAssetTrack.naturalSize.width)
//            compositionAddVideo.preferredTransform = frontalTransform
//        }
//
//        mutableCompositionVideoTrack.append(compositionAddVideo)
//        mutableCompositionAudioTrack.append(compositionAddAudio)
//        mutableCompositionAudioOfVideoTrack.append(compositionAddAudioOfVideo)
//
//        do {
//            try mutableCompositionVideoTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero,
//                                                                                aVideoAssetTrack.timeRange.duration),
//                                                                of: aVideoAssetTrack,
//                                                                at: kCMTimeZero)
//
//            //In my case my audio file is longer then video file so i took videoAsset duration
//            //instead of audioAsset duration
//            try mutableCompositionAudioTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero,
//                                                                                aVideoAssetTrack.timeRange.duration),
//                                                                of: aAudioAssetTrack,
//                                                                at: kCMTimeZero)
//
//            // adding audio (of the video if exists) asset to the final composition
//            if let aAudioOfVideoAssetTrack = aAudioOfVideoAssetTrack {
//                try mutableCompositionAudioOfVideoTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero,
//                                                                                           aVideoAssetTrack.timeRange.duration),
//                                                                           of: aAudioOfVideoAssetTrack,
//                                                                           at: kCMTimeZero)
//            }
//        } catch {
//            print(error.localizedDescription)
//        }
//
//        // Exporting
//        let savePathUrl: URL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/newVideo.mp4")
//        do { // delete old video
//            try FileManager.default.removeItem(at: savePathUrl)
//        } catch { print(error.localizedDescription) }
//
//        let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
//        assetExport.outputFileType = AVFileTypeMPEG4
//        assetExport.outputURL = savePathUrl
//        assetExport.shouldOptimizeForNetworkUse = true
//
//        assetExport.exportAsynchronously { () -> Void in
//            switch assetExport.status {
//            case AVAssetExportSessionStatus.completed:
//                print("success")
//                completion(nil, savePathUrl)
//            case AVAssetExportSessionStatus.failed:
//                print("failed \(assetExport.error?.localizedDescription ?? "error nil")")
//                completion(assetExport.error, nil)
//            case AVAssetExportSessionStatus.cancelled:
//                print("cancelled \(assetExport.error?.localizedDescription ?? "error nil")")
//                completion(assetExport.error, nil)
//            default:
//                print("complete")
//                completion(assetExport.error, nil)
//            }
//        }
//
//    }
    
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
