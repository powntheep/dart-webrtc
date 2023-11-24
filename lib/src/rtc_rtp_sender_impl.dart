import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util';

import 'package:dart_webrtc/src/media_stream_impl.dart';
import 'package:web/helpers.dart' as html
    hide RTCRtpEncodingParametersExtension, RTCRtpCodecExtension;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'media_stream_track_impl.dart';
import 'rtc_dtmf_sender_impl.dart';

class RTCRtpSenderWeb extends RTCRtpSender {
  RTCRtpSenderWeb(this._jsRtpSender, this._ownsTrack);

  factory RTCRtpSenderWeb.fromJsSender(html.RTCRtpSender jsRtpSender) {
    return RTCRtpSenderWeb(jsRtpSender, jsRtpSender.track != null);
  }

  final html.RTCRtpSender _jsRtpSender;
  bool _ownsTrack = false;

  @override
  Future<void> replaceTrack(MediaStreamTrack? track) async {
    try {
      if (track != null) {
        var nativeTrack = track as MediaStreamTrackWeb;
        _jsRtpSender.replaceTrack(nativeTrack.jsTrack);
      } else {
        _jsRtpSender.replaceTrack(null);
      }
    } on Exception catch (e) {
      throw 'Unable to RTCRtpSender::replaceTrack: ${e.toString()}';
    }
  }

  @override
  Future<void> setTrack(MediaStreamTrack? track,
      {bool takeOwnership = true}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> setStreams(List<MediaStream> streams) async {
    try {
      final nativeStreams = streams.cast<MediaStreamWeb>();
      for (var i = 0; i < nativeStreams.length; i++) {
        var nativeStream = nativeStreams[i];
        _jsRtpSender.setStreams(nativeStream.jsStream);
      }
    } on Exception catch (e) {
      throw 'Unable to RTCRtpSender::setStreams: ${e.toString()}';
    }
  }

  @override
  RTCRtpParameters get parameters {
    final parameters = _jsRtpSender.getParameters();
    final response = RTCRtpParameters(
        transactionId: parameters.transactionId,
        rtcp: RTCRTCPParameters(
          parameters.rtcp.cname,
          parameters.rtcp.reducedSize,
        ),
        headerExtensions: parameters.headerExtensions.toDart.map((e) {
          final headerExtension = e as html.RTCRtpHeaderExtensionParameters;
          return RTCHeaderExtension(
            uri: headerExtension.uri,
            id: headerExtension.id,
            encrypted: headerExtension.encrypted,
          );
        }).toList(),
        degradationPreference: RTCDegradationPreference.BALANCED,
        encodings: parameters.encodings.toDart.map((e) {
          final encoding = e as html.RTCRtpEncodingParameters;
          return RTCRtpEncoding(
            rid: encoding.rid,
            active: encoding.active,
            maxBitrate: encoding.maxBitrate,
            maxFramerate: encoding.maxFramerate.toInt(),
            scaleResolutionDownBy: encoding.scaleResolutionDownBy.toDouble(),
            scalabilityMode: encoding.scalabilityMode,
          );
        }).toList(),
        codecs: parameters.codecs.toDart.map((e) {
          final codec = e as html.RTCRtpCodecParameters;
          return RTCRTPCodec(
            payloadType: codec.payloadType,
            name: codec.mimeType.split('/').lastOrNull,
            clockRate: codec.clockRate,
            kind: codec.mimeType.split('/').firstOrNull,
            numChannels: codec.channels,
            parameters:
                Map.fromIterable(codec.sdpFmtpLine?.split('\n').map((e) {
                      final parts = e.split('=');
                      return MapEntry(
                          parts.firstOrNull?.trim(), parts.lastOrNull ?? '');
                    }) ??
                    []),
          );
        }).toList());

    return response;
  }

  @override
  Future<bool> setParameters(RTCRtpParameters parameters) async {
    try {
      var oldParameters = _jsRtpSender.getParameters();

      final encodings = JSArray();

      parameters.encodings?.forEach((element) {
        encodings.toDart.add(element.toMap().jsify());
      });

      oldParameters.encodings = encodings;

      _jsRtpSender.setParameters(oldParameters);
      return Future<bool>.value(true);
    } on Exception catch (e) {
      throw 'Unable to RTCRtpSender::setParameters: ${e.toString()}';
    }
  }

  @override
  Future<List<StatsReport>> getStats() async {
    final stats = await _jsRtpSender.getStats().toDart as html.RTCStatsReport;
    var reports = <StatsReport>[];

    stats.forEach((JSObject report) {
      final value = report.dartify() as Map;
      reports.add(
          StatsReport(value['id'], value['type'], value['timestamp'], value));
    }.toJS);
    return reports;
  }

  @override
  MediaStreamTrack? get track {
    if (null != _jsRtpSender.track) {
      return MediaStreamTrackWeb(_jsRtpSender.track!);
    }
    return null;
  }

  @override
  String get senderId => '${_jsRtpSender.hashCode}';

  @override
  bool get ownsTrack => _ownsTrack;

  @override
  RTCDTMFSender get dtmfSender => RTCDTMFSenderWeb(
        _jsRtpSender.dtmf!,
      );

  @override
  Future<void> dispose() async {}

  html.RTCRtpSender get jsRtpSender => _jsRtpSender;
}

extension RTCStatsReportExtension2 on html.RTCStatsReport {
  external void forEach(JSFunction callback);
}

extension RTCRtpEncodingParametersExtension on html.RTCRtpEncodingParameters {
  external set priority(html.RTCPriorityType value);
  external html.RTCPriorityType get priority;
  external set networkPriority(html.RTCPriorityType value);
  external html.RTCPriorityType get networkPriority;
  external set scalabilityMode(String? value);
  external String? get scalabilityMode;
  external set active(bool value);
  external bool get active;
  external set maxBitrate(int value);
  external int get maxBitrate;
  external set maxFramerate(num value);
  external num get maxFramerate;
  external set scaleResolutionDownBy(num value);
  external num get scaleResolutionDownBy;
}

extension RTCRtpCodecExtension on html.RTCRtpCodec {
  external set mimeType(String value);
  external String get mimeType;
  external set clockRate(int value);
  external int get clockRate;
  external set channels(int? value);
  external int? get channels;
  external set sdpFmtpLine(String? value);
  external String? get sdpFmtpLine;
}
