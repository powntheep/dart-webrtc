import 'dart:async';
import 'dart:js_interop';
import 'package:web/helpers.dart' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'media_stream_track_impl.dart';

class MediaStreamWeb extends MediaStream {
  MediaStreamWeb(this.jsStream, String ownerTag) : super(jsStream.id, ownerTag);
  final html.MediaStream jsStream;

  @override
  Future<void> getMediaTracks() {
    return Future.value();
  }

  @override
  Future<void> addTrack(MediaStreamTrack track, {bool addToNative = true}) {
    if (addToNative) {
      var _native = track as MediaStreamTrackWeb;
      jsStream.addTrack(_native.jsTrack);
    }
    return Future.value();
  }

  @override
  Future<void> removeTrack(MediaStreamTrack track,
      {bool removeFromNative = true}) async {
    if (removeFromNative) {
      var _native = track as MediaStreamTrackWeb;
      jsStream.removeTrack(_native.jsTrack);
    }
  }

  @override
  List<MediaStreamTrack> getAudioTracks() {
    final audioTracks = <MediaStreamTrack>[];
    final tracks = jsStream.getAudioTracks().toDart;
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i] as html.MediaStreamTrack;
      audioTracks.add(MediaStreamTrackWeb(track));
    }

    return audioTracks;
  }

  @override
  List<MediaStreamTrack> getVideoTracks() {
    final videoTracks = <MediaStreamTrack>[];
    final tracks = jsStream.getVideoTracks().toDart;
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i] as html.MediaStreamTrack;
      videoTracks.add(MediaStreamTrackWeb(track));
    }
    return videoTracks;
  }

  @override
  List<MediaStreamTrack> getTracks() {
    return <MediaStreamTrack>[...getAudioTracks(), ...getVideoTracks()];
  }

  @override
  bool? get active => jsStream.active;

  @override
  Future<MediaStream> clone() async {
    return MediaStreamWeb(jsStream.clone(), ownerTag);
  }
}
