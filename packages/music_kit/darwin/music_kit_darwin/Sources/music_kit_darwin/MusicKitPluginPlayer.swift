//
//  MusicKitPluginPlayer.swift
//  music_kit
//
//  Created by Longjiang Lv on 2022/5/26.
//

import Foundation
import MusicKit
import Combine

#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

let kErrorPlay = "ERR_PLAYER_PLAY"
let kErrorPrepareToPlay = "ERR_PLAYER_PREPARE_TO_PLAY"
let kErrorSkipToNext = "ERR_PLAYER_SKIP_TO_NEXT"
let kErrorSkipToPrevious = "ERR_PLAYER_SKIP_TO_PREVIOUS"
let kErrorPlayerUnavailable = "ERR_PLAYER_UNAVAILABLE"

/// What a macOS 12/13 install gets from the transport: library reads work
/// there (they are plain HTTP), playback does not.
func playerUnavailableError() -> FlutterError {
  FlutterError(
    code: kErrorPlayerUnavailable,
    message: "Apple Music playback requires macOS 14 or later.",
    details: nil
  )
}

/// Every player call is gated on the OS that actually has
/// `ApplicationMusicPlayer`; `handle` routes them through here.
@available(macOS 14.0, iOS 15.0, *)
extension MusicKitPlugin {
  func handlePlayerMethod(_ key: MethodKeys, call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch key {
    case .isPreparedToPlay:
      isPreparedToPlay(result)

    case .playbackTime:
      playbackTime(result)

    case .seekToPosition:
      seekToPosition(call.arguments as? Double ?? 0, result: result)

    case .musicPlayerState:
      musicPlayerState(result)

    case .pause:
      pause(result)

    case .play:
      play(result)

    case .prepareToPlay:
      prepareToPlay(result)

    case .restartCurrentEntry:
      restartCurrentEntry(result)

    case .skipToNextEntry:
      skipToNextEntry(result)

    case .skipToPreviousEntry:
      skipToPreviousEntry(result)

    case .stop:
      stop(result)

    case .clearQueue:
      clearQueue(result)

    case .setQueue:
      let arguments = call.arguments as! JSONObject
      setQueue(
        itemType: arguments["type"] as! String,
        itemObject: arguments["item"] as! ResourceObject,
        result: result
      )

    case .setQueueWithItems:
      let arguments = call.arguments as! JSONObject
      setQueue(
        itemType: arguments["type"] as! String,
        itemObjects: arguments["items"] as! Array<ResourceObject>,
        startingAt: arguments["startingAt"] as? Int,
        result: result
      )

    case .repeatMode:
      repeatMode(result)

    case .setRepeatMode:
      setRepeatMode(call.arguments as! Int, result: result)

    case .toggleRepeatMode:
      toggleRepeatMode(result)

    case .shuffleMode:
      shuffleMode(result)

    case .setShuffleMode:
      setShuffleMode(call.arguments as! Int, result: result)

    case .toggleShuffleMode:
      toggleShuffleMode(result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func isPreparedToPlay(_ result: @escaping FlutterResult) {
    result(musicPlayer.isPreparedToPlay)
  }

  func playbackTime(_ result: @escaping FlutterResult) {
    result(musicPlayer.playbackTime)
  }

  /// Moves the playhead. `MusicPlayer.playbackTime` is settable, which is what
  /// the scrubber drives; the upstream plugin only exposed the getter.
  func seekToPosition(_ seconds: Double, result: @escaping FlutterResult) {
    guard seconds.isFinite && seconds >= 0 else {
      result(FlutterError(code: kErrorPlay, message: "Invalid seek position.", details: nil))
      return
    }
    musicPlayer.playbackTime = seconds
    result(nil)
  }

  func musicPlayerState(_ result: @escaping FlutterResult) {
    result(musicPlayer.state.jsonObject())
  }

  func pause(_ result: @escaping FlutterResult) {
    musicPlayer.pause()
    result(nil)
  }

  func play(_ result: @escaping FlutterResult) {
    Task {
      do {
        try await musicPlayer.play()
        result(nil)
      } catch {
        result(FlutterError(code: kErrorPlay, message: error.localizedDescription, details: nil))
      }
    }
  }

  func prepareToPlay(_ result: @escaping FlutterResult) {
    Task {
      do {
        try await musicPlayer.prepareToPlay()
        result(nil)
      } catch {
        result(FlutterError(code: kErrorPrepareToPlay, message: error.localizedDescription, details: nil))
      }
    }
  }

  func restartCurrentEntry(_ result: @escaping FlutterResult) {
    musicPlayer.restartCurrentEntry()
    result(nil)
  }

  func skipToNextEntry(_ result: @escaping FlutterResult) {
    Task {
      do {
        try await musicPlayer.skipToNextEntry()
        result(nil)
      } catch {
        result(FlutterError(code: kErrorSkipToNext, message: error.localizedDescription, details: nil))
      }
    }
  }

  func skipToPreviousEntry(_ result: @escaping FlutterResult) {
    Task {
      do {
        try await musicPlayer.skipToPreviousEntry()
        result(nil)
      } catch {
        result(FlutterError(code: kErrorSkipToPrevious, message: error.localizedDescription, details: nil))
      }
    }
  }

  func stop(_ result: @escaping FlutterResult) {
    musicPlayer.stop()
    result(nil)
  }

  /// Empties the queue and retires the entry the system player published to
  /// the now-playing centre. `stop()` alone leaves a paused entry behind:
  /// the queue stays loaded, so macOS keeps showing it next to whatever the
  /// app's own session publishes afterwards.
  func clearQueue(_ result: @escaping FlutterResult) {
    musicPlayer.queue = []
    result(nil)
  }
}

enum MusicItemType {
  case album
  case artist
  case curator
  case genre
  case musicVideo
  case playlist
  case radioShow
  case recordLabel
  case song
  case station
  case track

  init?(_ value: String) {
    switch value.lowercased() {
    case "albums": self = .album
    case "artists": self = .artist
    case "curators": self = .curator
    case "genres": self = .genre
    case "music-videos": self = .musicVideo
    case "playlists": self = .playlist
    case "radio-shows": self = .radioShow
    case "record-labels": self = .recordLabel
    case "songs": self = .song
    case "stations": self = .station
    case "tracks": self = .track
    default: return nil
    }
  }
}

extension MusicKitPlugin {
  /// Stands in for the two player channels where the system has no
  /// `ApplicationMusicPlayer` (macOS 12 and 13): the Dart side subscribes
  /// eagerly, and a missing handler would surface as a channel error on every
  /// launch.
  class SilentStreamHandler: MusicKitPluginStreamHandler, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
      eventSink = events
      return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      eventSink = nil
      return nil
    }
  }
}

@available(macOS 14.0, iOS 15.0, *)
extension MusicKitPlugin {
  class MusicPlayerStreamHandler: MusicKitPluginStreamHandler, FlutterStreamHandler {
    let musicPlayer: ApplicationMusicPlayer
    private var playerTask: Task<(), Never>?
    private var cancellable: AnyCancellable?

    init(musicPlayer: ApplicationMusicPlayer) {
      self.musicPlayer = musicPlayer
      super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
      eventSink = events

      cancellable = musicPlayer.state
        .objectWillChange
        .makeConnectable()
        .autoconnect()
        .sink { [weak self] in
          DispatchQueue.main.async { [weak self] in
            self?.eventSink?(self?.musicPlayer.state.jsonObject())
          }
        }

      return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      eventSink = nil
      playerTask?.cancel()
      playerTask = nil
      cancellable?.cancel()
      cancellable = nil
      return nil
    }
  }
}

@available(macOS 14.0, iOS 15.0, *)
extension MusicPlayer.State: JSONEncodable {
  enum CodingKeys: String, CodingKey {
    case playbackRate
    case playbackStatus
    case repeatMode
    case shuffleMode
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(playbackRate, forKey: .playbackRate)
    try container.encode(playbackStatus.intValue, forKey: .playbackStatus)
    try container.encode(repeatMode?.intValue, forKey: .repeatMode)
    try container.encode(shuffleMode?.intValue, forKey: .shuffleMode)
  }
}

@available(macOS 14.0, iOS 15.0, *)
extension MusicPlayer.PlaybackStatus {
  public var intValue: Int {
    switch self {
    case .stopped: return 0
    case .playing: return 1
    case .paused: return 2
    case .interrupted: return 3
    case .seekingBackward: return 4
    case .seekingForward: return 5
    @unknown default:
      return 0
    }
  }
}

@available(macOS 14.0, iOS 15.0, *)
extension MusicPlayer.RepeatMode {
  public var intValue: Int {
    switch self {
    case .none: return 0
    case .one: return 1
    case .all: return 2
    @unknown default:
      return 0
    }
  }

  init(_ intValue: Int) {
    switch intValue {
    case 0:
      self = .none
    case 1:
      self = .one
    case 2:
      self = .all
    default:
      self = .none
    }
  }
}

@available(macOS 14.0, iOS 15.0, *)
extension MusicPlayer.ShuffleMode {
  public var intValue: Int {
    switch self {
    case .off: return 0
    case .songs: return 1
    @unknown default:
      return 0
    }
  }

  init(_ intValue: Int) {
    switch intValue {
    case 0:
      self = .off
    case 1:
      self = .songs
    default:
      self = .off
    }
  }
}
