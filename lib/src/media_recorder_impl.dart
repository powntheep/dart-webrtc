import 'dart:async';
import 'dart:js_interop';
import 'package:web/helpers.dart' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'media_stream_impl.dart';

class MediaRecorderWeb extends MediaRecorder {
  late html.MediaRecorder _recorder;
  late Completer<String> _completer;

  @override
  Future<void> start(
    String path, {
    MediaStreamTrack? videoTrack,
    MediaStreamTrack? audioTrack,
    RecorderAudioChannel? audioChannel,
    int? rotation,
  }) {
    throw 'Use startWeb on Flutter Web!';
  }

  @override
  void startWeb(
    MediaStream stream, {
    Function(dynamic blob, bool isLastOne)? onDataChunk,
    String mimeType = 'video/webm',
    int timeSlice = 1000,
  }) {
    var _native = stream as MediaStreamWeb;
    _recorder = html.MediaRecorder(_native.jsStream,
        {'mimeType': mimeType}.jsify() as html.MediaRecorderOptions);
    if (onDataChunk == null) {
      var _chunks = <html.Blob>[];
      _completer = Completer<String>();
      _recorder.addEventListener(
          'dataavailable',
          (html.Event event) {
            final blob = event.data as html.Blob;
            if (blob.size > 0) {
              _chunks.add(blob);
            }
            if (_recorder.state == 'inactive') {
              final blob = html.Blob(_chunks.jsify() as JSArray,
                  html.BlobPropertyBag(type: mimeType));
              _completer.complete(html.URL.createObjectURL(blob as JSObject));
            }
          }.toJS);
      _recorder.onerror = ((html.Event error) {
        _completer.completeError(error);
      }).toJS;
    } else {
      _recorder.addEventListener(
          'dataavailable',
          (html.Event event) {
            onDataChunk(
              event.data,
              _recorder.state == 'inactive',
            );
          }.toJS);
    }
    _recorder.start(timeSlice);
  }

  @override
  Future<dynamic> stop() {
    _recorder.stop();
    return _completer.future;
  }
}

extension EventDataExtension on html.Event {
  external JSAny get data;
}
