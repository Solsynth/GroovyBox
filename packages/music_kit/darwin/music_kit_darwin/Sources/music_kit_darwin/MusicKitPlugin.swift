import MusicKit
import Combine

#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import AppKit
#endif

public class MusicKitPlugin: NSObject, FlutterPlugin {
  /// The application music player. Only reachable behind an availability
  /// check: on macOS 12 and 13 `ApplicationMusicPlayer` is in the SDK but not
  /// in the system, and touching `.shared` there traps. Library reads stay
  /// usable on those versions; playback is what needs macOS 14.
  @available(macOS 14.0, iOS 15.0, *)
  internal var musicPlayer: ApplicationMusicPlayer { ApplicationMusicPlayer.shared }
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    
    let channel = FlutterMethodChannel(name: "plugins.misi.app/music_kit", binaryMessenger: messenger)
    let instance = MusicKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    let musicSubscriptionEventChannel = FlutterEventChannel(
      name: "plugins.misi.app/music_kit/music_subscription",
      binaryMessenger: messenger,
      codec: FlutterStandardMethodCodec.sharedInstance()
    )
    musicSubscriptionEventChannel.setStreamHandler(MusicSubscriptionStreamHandler())
    
    let musicPlayerStateEventChannel = FlutterEventChannel(
      name: "plugins.misi.app/music_kit/player_state",
      binaryMessenger: messenger
    )
    let musicPlayerQueueEventChannel = FlutterEventChannel(
      name: "plugins.misi.app/music_kit/player_queue",
      binaryMessenger: messenger
    )

    if #available(macOS 14.0, iOS 15.0, *) {
      musicPlayerStateEventChannel.setStreamHandler(MusicPlayerStreamHandler(musicPlayer: instance.musicPlayer))
      musicPlayerQueueEventChannel.setStreamHandler(MusicPlayerQueueStreamHandler(musicPlayer: instance.musicPlayer))
    } else {
      // A silent handler rather than none: the Dart side subscribes eagerly, and
      // a missing handler would surface as a channel error on every launch.
      musicPlayerStateEventChannel.setStreamHandler(SilentStreamHandler())
      musicPlayerQueueEventChannel.setStreamHandler(SilentStreamHandler())
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let methodKey = MethodKeys(rawValue: call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }
    
    switch methodKey {
    case .authorizationStatus:
      authorizationStatus(result)
        
    case .requestAuthorizationStatus:
      requestAuthorizationStatus(result)
      
    case .requestDeveloperToken:
      developerToken(result)
      
    case .requestUserToken:
      let arguments = call.arguments as! JSONObject
      fetchUserToken(developerToken: arguments["developerToken"] as! String, result: result)
      
    case .currentCountryCode:
      currentCountryCode(result)

    default:
      // Everything else drives the player, which only exists where the OS
      // ships one. One gate here keeps the availability annotation out of
      // the rest of the file.
      if #available(macOS 14.0, iOS 15.0, *) {
        handlePlayerMethod(methodKey, call: call, result: result)
      } else {
        result(playerUnavailableError())
      }
    }
  }
}

extension MusicKitPlugin {
  class MusicKitPluginStreamHandler: NSObject {
    var eventSink: FlutterEventSink? = nil
  }
}

extension FlutterError {
  public convenience init(code: String, message: String?) {
    self.init(code: code, message: message, details: nil)
  }
}

