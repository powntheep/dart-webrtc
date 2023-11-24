import 'dart:js_interop';
import 'dart:js_util';

import 'package:dart_webrtc/src/rtc_rtp_sender_impl.dart';
import 'package:web/helpers.dart' as html
    hide RTCRtpEncodingParametersExtension, RTCRtpCodecExtension;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'media_stream_track_impl.dart';

class RTCRtpReceiverWeb extends RTCRtpReceiver {
  RTCRtpReceiverWeb(this._jsRtpReceiver);

  /// private:
  final html.RTCRtpReceiver _jsRtpReceiver;

  @override
  Future<List<StatsReport>> getStats() async {
    final stats = await _jsRtpReceiver.getStats().toDart as html.RTCStatsReport;
    var reports = <StatsReport>[];

    stats.forEach((JSObject report) {
      final value = report.dartify() as Map;
      reports.add(
          StatsReport(value['id'], value['type'], value['timestamp'], value));
    }.toJS);
    return reports;
  }

  /// The WebRTC specification only defines RTCRtpParameters in terms of senders,
  /// but this API also applies them to receivers, similar to ORTC:
  /// http://ortc.org/wp-content/uploads/2016/03/ortc.html#rtcrtpparameters*.
  @override
  RTCRtpParameters get parameters {
    final parameters = _jsRtpReceiver.getParameters();
    final response = RTCRtpParameters(
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
  MediaStreamTrack get track => MediaStreamTrackWeb(_jsRtpReceiver.track);

  @override
  String get receiverId => '${_jsRtpReceiver.hashCode}';

  html.RTCRtpReceiver get jsRtpReceiver => _jsRtpReceiver;
}
