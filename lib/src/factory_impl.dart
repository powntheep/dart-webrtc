import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:dart_webrtc/src/rtc_rtp_capailities_imp.dart';
import 'package:web/helpers.dart' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'frame_cryptor_impl.dart';
import 'media_recorder_impl.dart';
import 'media_stream_impl.dart';
import 'navigator_impl.dart';
import 'rtc_peerconnection_impl.dart';

// @JS('RTCRtpSender')
// @staticInterop
// class RTCRtpSenderJs {
//   external static Object getCapabilities(String kind);
// }

// @JS('RTCRtpReceiver')
// @staticInterop
// class RTCRtpReceiverJs {
//   external static Object getCapabilities(String kind);
// }

class RTCFactoryWeb extends RTCFactory {
  RTCFactoryWeb._internal();
  static final instance = RTCFactoryWeb._internal();

  @override
  Future<RTCPeerConnection> createPeerConnection(
      Map<String, dynamic> configuration,
      [Map<String, dynamic>? constraints]) async {
    final constr = (constraints != null && constraints.isNotEmpty)
        ? constraints
        : {
            'mandatory': {},
            'optional': [
              {'DtlsSrtpKeyAgreement': true},
            ],
          };
    final jsRtcPc = html.RTCPeerConnection(
        {...constr, ...configuration}.jsify() as html.RTCConfiguration);
    final _peerConnectionId = base64Encode(jsRtcPc.toString().codeUnits);
    return RTCPeerConnectionWeb(_peerConnectionId, jsRtcPc);
  }

  @override
  Future<MediaStream> createLocalMediaStream(String label) async {
    final jsMs = html.MediaStream();
    return MediaStreamWeb(jsMs, 'local');
  }

  @override
  MediaRecorder mediaRecorder() {
    return MediaRecorderWeb();
  }

  @override
  VideoRenderer videoRenderer() {
    throw UnimplementedError();
  }

  @override
  Navigator get navigator => NavigatorWeb();

  @override
  FrameCryptorFactory get frameCryptorFactory =>
      FrameCryptorFactoryImpl.instance;

  @override
  Future<RTCRtpCapabilities> getRtpReceiverCapabilities(String kind) async {
    var caps = html.RTCRtpReceiver.getCapabilities(kind);
    if (caps == null) {
      throw Exception('Capabilities for $kind are not available');
    }
    return RTCRtpCapabilitiesWeb.fromJsObject(
      caps,
      // headerExtensions: caps.headerExtensions.toDart.map((e) {
      //   final ext = e as html.RTCRtpHeaderExtensionCapability;
      //   return RTCRtpHeaderExtensionCapability(
      //     ext.uri,
      //   );
      // }).toList(),
      // codecs: caps.codecs.toDart.map((e) {
      //   final codec = e.dartify() as Map<String, dynamic>;
      //   return RTCRtpCodecCapability(
      //     clockRate: codec['clockRate'],
      //     mimeType: codec['mimeType'],
      //     channels: codec['channels'],
      //     sdpFmtpLine: codec['sdpFmtpLine'],
      //   );
      // }).toList(),
    );
  }

  @override
  Future<RTCRtpCapabilities> getRtpSenderCapabilities(String kind) async {
    var caps = html.RTCRtpSender.getCapabilities(kind);
    if (caps == null) {
      throw Exception('Capabilities for $kind are not available');
    }

    return RTCRtpCapabilitiesWeb.fromJsObject(caps);

    // return RTCRtpCapabilities(
    //   headerExtensions: caps.headerExtensions.toDart.map((e) {
    //     final ext = e as html.RTCRtpHeaderExtensionCapability;
    //     return RTCRtpHeaderExtensionCapability(
    //       ext.uri,
    //     );
    //   }).toList(),
    //   codecs: caps.codecs.toDart.map((e) {
    //     final codec = e.dartify() as Map<String, dynamic>;
    //     return RTCRtpCodecCapability(
    //       clockRate: codec['clockRate'],
    //       mimeType: codec['mimeType'],
    //       channels: codec['channels'],
    //       sdpFmtpLine: codec['sdpFmtpLine'],
    //     );
    //   }).toList(),
    // );
  }
}

Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration,
    [Map<String, dynamic>? constraints]) {
  return RTCFactoryWeb.instance
      .createPeerConnection(configuration, constraints);
}

Future<MediaStream> createLocalMediaStream(String label) {
  return RTCFactoryWeb.instance.createLocalMediaStream(label);
}

Future<RTCRtpCapabilities> getRtpReceiverCapabilities(String kind) async {
  return RTCFactoryWeb.instance.getRtpReceiverCapabilities(kind);
}

Future<RTCRtpCapabilities> getRtpSenderCapabilities(String kind) async {
  return RTCFactoryWeb.instance.getRtpSenderCapabilities(kind);
}

MediaRecorder mediaRecorder() {
  return RTCFactoryWeb.instance.mediaRecorder();
}

VideoRenderer videoRenderer() {
  return RTCFactoryWeb.instance.videoRenderer();
}

Navigator get navigator => RTCFactoryWeb.instance.navigator;

FrameCryptorFactory get frameCryptorFactory => FrameCryptorFactoryImpl.instance;

MediaDevices get mediaDevices => navigator.mediaDevices;
