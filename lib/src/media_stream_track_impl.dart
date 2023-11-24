import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js;
import 'dart:typed_data';

import 'package:web/helpers.dart' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

class MediaStreamTrackWeb extends MediaStreamTrack {
  MediaStreamTrackWeb(this.jsTrack) {
    jsTrack.onended = (html.Event event) {
      onEnded?.call();
    }.toJS;
    jsTrack.onmute = (html.Event event) {
      onMute?.call();
    }.toJS;
    jsTrack.onunmute = (html.Event event) {
      onUnMute?.call();
    }.toJS;
  }

  final html.MediaStreamTrack jsTrack;

  @override
  String? get id => jsTrack.id;

  @override
  String? get kind => jsTrack.kind;

  @override
  String? get label => jsTrack.label;

  @override
  bool get enabled => jsTrack.enabled;

  @override
  bool? get muted => jsTrack.muted;

  @override
  set enabled(bool? b) {
    jsTrack.enabled = b == true;
  }

  @override
  Map<String, dynamic> getConstraints() {
    return jsTrack.getConstraints() as Map<String, dynamic>;
  }

  @override
  Future<void> applyConstraints([Map<String, dynamic>? constraints]) async {
    // TODO(wermathurin): Wait for: https://github.com/dart-lang/sdk/commit/1a861435579a37c297f3be0cf69735d5b492bc6c
    // to be merged to use jsTrack.applyConstraints() directly
    final arg = js.jsify(constraints ?? {});

    final _val = await js.promiseToFuture<void>(
        js.callMethod(jsTrack, 'applyConstraints', [arg]));
    return _val;
  }

  // TODO(wermathurin): https://github.com/dart-lang/sdk/issues/44319
  // @override
  // MediaTrackCapabilities getCapabilities() {
  //   var _converted = jsTrack.getCapabilities();
  //   print(_converted['aspectRatio'].runtimeType);
  //   return null;
  // }

  @override
  Map<String, dynamic> getSettings() {
    return jsTrack.getSettings() as Map<String, dynamic>;
  }

  @override
  Future<ByteBuffer> captureFrame() async {
    final imageCapture = html.ImageCapture(jsTrack);
    final bitmap = (await imageCapture.grabFrame().toDart) as html.ImageBitmap;
    final canvas = html.createCanvasElement();
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    final renderer =
        canvas.getContext('bitmaprenderer') as html.ImageBitmapRenderingContext;
    renderer.transferFromImageBitmap(bitmap);
    final completer = Completer<html.Blob>();
    final successCb = (html.Blob blob) {
      completer.complete(blob);
    }.toJS;
    canvas.toBlob(successCb);
    final blob = await completer.future;
    final array = (await blob.arrayBuffer().toDart).dartify() as ByteBuffer;

    bitmap.close();
    return array;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> stop() async {
    jsTrack.stop();
  }

  @override
  Future<bool> hasTorch() {
    return Future.value(false);
  }

  @override
  Future<void> setTorch(bool torch) {
    throw UnimplementedError('The web implementation does not support torch');
  }

  @override
  Future<MediaStreamTrack> clone() async {
    return MediaStreamTrackWeb(jsTrack.clone());
  }
}
