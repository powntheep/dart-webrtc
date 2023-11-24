import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util';
import 'package:web/helpers.dart' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'media_stream_impl.dart';
import 'utils.dart';

class MediaDevicesWeb extends MediaDevices {
  @override
  Future<MediaStream> getUserMedia(
      Map<String, dynamic> mediaConstraints) async {
    try {
      if (!isMobile) {
        if (mediaConstraints['video'] is Map &&
            mediaConstraints['video']['facingMode'] != null) {
          mediaConstraints['video'].remove('facingMode');
        }
      }

      mediaConstraints.putIfAbsent('video', () => false);
      mediaConstraints.putIfAbsent('audio', () => false);

      if (hasProperty(html.window.navigator, 'mediaDevices') &&
          hasProperty(html.window.navigator.mediaDevices, 'getUserMedia')) {
        final mediaDevices = html.window.navigator.mediaDevices;

        final jsStream = (await mediaDevices
            .getUserMedia(
                mediaConstraints.jsify() as html.MediaStreamConstraints)
            .toDart) as html.MediaStream;
        return MediaStreamWeb(jsStream, 'local');
      } else if (hasProperty(html.window.navigator, 'getUserMedia')) {
        final completer = Completer<html.MediaStream>();
        final successCb = (html.MediaStream stream) {
          completer.complete(stream);
        }.toJS;
        final errorCb = (JSObject error) {
          completer.completeError(error);
        }.toJS;
        html.window.navigator.getUserMedia(
            mediaConstraints.jsify() as html.MediaStreamConstraints,
            successCb,
            errorCb);
        final jsStream = await completer.future;

        return MediaStreamWeb(jsStream, 'local');
      } else {
        throw Exception('getUserMedia is not available on this browser');
      }
    } catch (e) {
      throw 'Unable to getUserMedia: ${e.toString()}';
    }
  }

  @override
  Future<MediaStream> getDisplayMedia(
      Map<String, dynamic> mediaConstraints) async {
    try {
      if (hasProperty(html.window.navigator, 'mediaDevices') &&
          hasProperty(html.window.navigator.mediaDevices, 'getDisplayMedia')) {
        final mediaDevices = html.window.navigator.mediaDevices;
        final jsStream = (await mediaDevices
            .getDisplayMedia(
                mediaConstraints.jsify() as html.DisplayMediaStreamOptions)
            .toDart) as html.MediaStream;
        return MediaStreamWeb(jsStream, 'local');
      } else {
        throw Exception('getDisplayMedia is not available on this browser');
      }
    } catch (e) {
      throw 'Unable to getDisplayMedia: ${e.toString()}';
    }
  }

  @override
  Future<List<MediaDeviceInfo>> enumerateDevices() async {
    final devices = await getSources();

    return devices.map((e) {
      var input = e as html.MediaDeviceInfo;
      return MediaDeviceInfo(
        deviceId: input.deviceId,
        groupId: input.groupId,
        kind: input.kind,
        label: input.label,
      );
    }).toList();
  }

  @override
  Future<List<dynamic>> getSources() async {
    final devices =
        await html.window.navigator.mediaDevices.enumerateDevices().toDart;
    if (devices != null) {
      return devices.dartify() as List<dynamic>;
    }
    return [];
  }

  @override
  MediaTrackSupportedConstraints getSupportedConstraints() {
    final mediaDevices = html.window.navigator.mediaDevices;

    var _mapConstraints = mediaDevices.getSupportedConstraints();

    return MediaTrackSupportedConstraints(
        aspectRatio: _mapConstraints.aspectRatio,
        autoGainControl: _mapConstraints.autoGainControl,
        brightness: _mapConstraints.brightness,
        channelCount: _mapConstraints.channelCount,
        colorTemperature: _mapConstraints.colorTemperature,
        contrast: _mapConstraints.contrast,
        deviceId: _mapConstraints.deviceId,
        echoCancellation: _mapConstraints.echoCancellation,
        exposureCompensation: _mapConstraints.exposureCompensation,
        exposureMode: _mapConstraints.exposureMode,
        exposureTime: _mapConstraints.exposureTime,
        facingMode: _mapConstraints.facingMode,
        focusDistance: _mapConstraints.focusDistance,
        focusMode: _mapConstraints.focusMode,
        frameRate: _mapConstraints.frameRate,
        groupId: _mapConstraints.groupId,
        height: _mapConstraints.height,
        iso: _mapConstraints.iso,
        latency: _mapConstraints.latency,
        noiseSuppression: _mapConstraints.noiseSuppression,
        pan: _mapConstraints.pan,
        pointsOfInterest: _mapConstraints.pointsOfInterest,
        resizeMode: _mapConstraints.resizeMode,
        saturation: _mapConstraints.saturation,
        sampleRate: _mapConstraints.sampleRate,
        sampleSize: _mapConstraints.sampleSize,
        sharpness: _mapConstraints.sharpness,
        tilt: _mapConstraints.tilt,
        torch: _mapConstraints.torch,
        whiteBalanceMode: _mapConstraints.whiteBalanceMode,
        width: _mapConstraints.width,
        zoom: _mapConstraints.zoom);
  }

  @override
  Future<MediaDeviceInfo> selectAudioOutput(
      [AudioOutputOptions? options]) async {
    try {
      if (!hasProperty(html.window.navigator, 'mediaDevices')) {
        throw Exception('MediaDevices is missing');
      }
      final mediaDevices = html.window.navigator.mediaDevices;

      if (hasProperty(mediaDevices, 'selectAudioOutput')) {
        if (options != null) {
          final arg = options.jsify();
          final deviceInfo = (await mediaDevices
              .selectAudioOutput(arg as html.AudioOutputOptions)
              .toDart) as html.MediaDeviceInfo;

          return MediaDeviceInfo(
            kind: deviceInfo.kind,
            label: deviceInfo.label,
            deviceId: deviceInfo.deviceId,
            groupId: deviceInfo.groupId,
          );
        } else {
          final deviceInfo = (await mediaDevices.selectAudioOutput().toDart)
              as html.MediaDeviceInfo;
          return MediaDeviceInfo(
            kind: deviceInfo.kind,
            label: deviceInfo.label,
            deviceId: deviceInfo.deviceId,
            groupId: deviceInfo.groupId,
          );
        }
      } else {
        throw UnimplementedError('selectAudioOutput is missing');
      }
    } catch (e) {
      throw 'Unable to selectAudioOutput: ${e.toString()}, Please try to use MediaElement.setSinkId instead.';
    }
  }

  @override
  set ondevicechange(Function(dynamic event)? listener) {
    try {
      if (!hasProperty(html.window.navigator, 'mediaDevices')) {
        throw Exception('MediaDevices is missing');
      }
      final mediaDevices = html.window.navigator.mediaDevices;

      mediaDevices.ondevicechange = (html.Event event) {
        listener?.call(event);
      }.toJS;
    } catch (e) {
      throw 'Unable to set ondevicechange: ${e.toString()}';
    }
  }

  @override
  Function(dynamic event)? get ondevicechange {
    try {
      if (!hasProperty(html.window.navigator, 'mediaDevices')) {
        throw Exception('MediaDevices is missing');
      }
      final mediaDevices = html.window.navigator.mediaDevices;

      mediaDevices.ondevicechange;
    } catch (e) {
      throw 'Unable to get ondevicechange: ${e.toString()}';
    }
    return null;
  }
}
