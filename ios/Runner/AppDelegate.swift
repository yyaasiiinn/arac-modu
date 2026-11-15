import Flutter
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var musicBridge: MusicBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MusicBridge") {
      musicBridge = MusicBridge(messenger: registrar.messenger())
    }
  }
}

/// Müzik uygulamasını (Apple Music / kitaplık) Flutter'dan kontrol eder.
class MusicBridge: NSObject {
  private let channel: FlutterMethodChannel
  private let player = MPMusicPlayerController.systemMusicPlayer

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "car_mode/music", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestAuth":
      MPMediaLibrary.requestAuthorization { status in
        DispatchQueue.main.async { result(status == .authorized) }
      }
    case "nowPlaying":
      result(nowPlaying(lastId: call.arguments as? String))
    case "play":
      player.play()
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "next":
      player.skipToNextItem()
      result(nil)
    case "previous":
      if player.currentPlaybackTime > 3 {
        player.skipToBeginning()
      } else {
        player.skipToPreviousItem()
      }
      result(nil)
    case "seek":
      if let s = call.arguments as? Double { player.currentPlaybackTime = s }
      result(nil)
    case "toggleShuffle":
      player.shuffleMode = (player.shuffleMode == .off) ? .songs : .off
      result(nil)
    case "toggleRepeat":
      switch player.repeatMode {
      case .all: player.repeatMode = .one
      case .one: player.repeatMode = .none
      default: player.repeatMode = .all
      }
      result(nil)
    case "playAll":
      guard MPMediaLibrary.authorizationStatus() == .authorized else { result(nil); return }
      player.setQueue(with: MPMediaQuery.songs())
      player.shuffleMode = .songs
      player.play()
      result(nil)
    case "playlists":
      guard MPMediaLibrary.authorizationStatus() == .authorized else { result([]); return }
      let lists = (MPMediaQuery.playlists().collections ?? []).compactMap { c -> [String: Any]? in
        guard let p = c as? MPMediaPlaylist else { return nil }
        return ["id": String(p.persistentID), "name": p.name ?? "Liste", "count": p.count]
      }
      result(lists)
    case "playPlaylist":
      guard let idStr = call.arguments as? String, let pid = UInt64(idStr) else { result(nil); return }
      let q = MPMediaQuery.playlists()
      q.addFilterPredicate(MPMediaPropertyPredicate(
        value: NSNumber(value: pid), forProperty: MPMediaPlaylistPropertyPersistentID))
      player.setQueue(with: q)
      player.play()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func nowPlaying(lastId: String?) -> [String: Any] {
    let t = player.currentPlaybackTime
    var repeatInt = 0
    if player.repeatMode == .all { repeatInt = 1 }
    if player.repeatMode == .one { repeatInt = 2 }
    var d: [String: Any] = [
      "isPlaying": player.playbackState == .playing,
      "position": t.isNaN ? 0.0 : t,
      "shuffle": player.shuffleMode != .off,
      "repeat": repeatInt,
    ]
    if let item = player.nowPlayingItem {
      let id = String(item.persistentID)
      d["id"] = id
      d["title"] = item.title ?? ""
      d["artist"] = item.artist ?? ""
      d["album"] = item.albumTitle ?? ""
      d["duration"] = item.playbackDuration
      if id != lastId,
        let img = item.artwork?.image(at: CGSize(width: 400, height: 400)),
        let data = img.jpegData(compressionQuality: 0.85)
      {
        d["artwork"] = FlutterStandardTypedData(bytes: data)
      }
    }
    return d
  }
}
