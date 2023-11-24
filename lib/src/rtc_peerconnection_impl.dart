import 'dart:async';
import 'dart:js_interop';

import 'package:platform_detect/platform_detect.dart';
import 'package:web/helpers.dart' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'media_stream_impl.dart';
import 'media_stream_track_impl.dart';
import 'rtc_data_channel_impl.dart';
import 'rtc_dtmf_sender_impl.dart';
import 'rtc_rtp_receiver_impl.dart';
import 'rtc_rtp_sender_impl.dart';
import 'rtc_rtp_transceiver_impl.dart';

/*
 *  PeerConnection
 */
class RTCPeerConnectionWeb extends RTCPeerConnection {
  RTCPeerConnectionWeb(this._peerConnectionId, this._jsPc) {
    _jsPc.ontrack = (html.RTCTrackEvent event) {
      onTrack?.call(
        RTCTrackEvent(
          track: MediaStreamTrackWeb(event.track),
          receiver: RTCRtpReceiverWeb(event.receiver),
          transceiver: RTCRtpTransceiverWeb(event.transceiver, null),
          streams: event.streams.toDart.map((e) {
            final stream = e as html.MediaStream;
            return MediaStreamWeb(stream, _peerConnectionId);
          }).toList(),
        ),
      );

      final streams = event.streams;
      for (final stream in streams.toDart) {
        final jsStream = stream as html.MediaStream;

        final _remoteStream = _remoteStreams.putIfAbsent(
            jsStream.id, () => MediaStreamWeb(jsStream, _peerConnectionId));

        onAddStream?.call(_remoteStream);

        jsStream.onaddtrack = (html.MediaStreamTrackEvent event) {
          final jsTrack = event.track;
          final track = MediaStreamTrackWeb(jsTrack);
          _remoteStream.addTrack(track, addToNative: false).then((_) {
            onAddTrack?.call(_remoteStream, track);
          });
        }.toJS;

        jsStream.onremovetrack = (html.MediaStreamTrackEvent event) {
          final jsTrack = event.track;
          final track = MediaStreamTrackWeb(jsTrack);
          _remoteStream.removeTrack(track, removeFromNative: false).then((_) {
            onRemoveTrack?.call(_remoteStream, track);
          });
        }.toJS;
      }
    }.toJS;

    _jsPc.ondatachannel = (html.RTCDataChannelEvent dataChannelEvent) {
      onDataChannel?.call(RTCDataChannelWeb(dataChannelEvent.channel!));
    }.toJS;

    _jsPc.onicecandidate = (html.RTCPeerConnectionIceEvent event) {
      if (event.candidate != null) {
        onIceCandidate?.call(RTCIceCandidate(
          event.candidate!.candidate,
          event.candidate!.sdpMid,
          event.candidate!.sdpMLineIndex,
        ));
      }
    }.toJS;

    _jsPc.oniceconnectionstatechange = ((html.Event _) {
      _iceConnectionState =
          iceConnectionStateForString(_jsPc.iceConnectionState);
      onIceConnectionState?.call(_iceConnectionState!);

      if (browser.isFirefox) {
        switch (_iceConnectionState!) {
          case RTCIceConnectionState.RTCIceConnectionStateNew:
            _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
            break;
          case RTCIceConnectionState.RTCIceConnectionStateChecking:
            _connectionState =
                RTCPeerConnectionState.RTCPeerConnectionStateConnecting;
            break;
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
            _connectionState =
                RTCPeerConnectionState.RTCPeerConnectionStateConnected;
            break;
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            _connectionState =
                RTCPeerConnectionState.RTCPeerConnectionStateFailed;
            break;
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            _connectionState =
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected;
            break;
          case RTCIceConnectionState.RTCIceConnectionStateClosed:
            _connectionState =
                RTCPeerConnectionState.RTCPeerConnectionStateClosed;
            break;
          default:
            break;
        }
        onConnectionState?.call(_connectionState!);
      }
    }).toJS;

    _jsPc.onicegatheringstatechange = ((html.Event _) {
      _iceGatheringState = iceGatheringStateforString(_jsPc.iceGatheringState);
      onIceGatheringState?.call(_iceGatheringState!);
    }).toJS;

    _jsPc.onsignalingstatechange = ((html.Event _) {
      _signalingState = signalingStateForString(_jsPc.signalingState);
      onSignalingState?.call(_signalingState!);
    }).toJS;

    if (!browser.isFirefox) {
      _jsPc.onconnectionstatechange = ((html.Event _) {
        _connectionState = peerConnectionStateForString(_jsPc.connectionState);
        onConnectionState?.call(_connectionState!);
      }).toJS;
    }

    _jsPc.onnegotiationneeded = ((html.Event _) {
      onRenegotiationNeeded?.call();
    }).toJS;
  }

  final String _peerConnectionId;
  late final html.RTCPeerConnection _jsPc;
  final _localStreams = <String, MediaStream>{};
  final _remoteStreams = <String, MediaStream>{};
  final _configuration = <String, dynamic>{};

  RTCSignalingState? _signalingState;
  RTCIceGatheringState? _iceGatheringState;
  RTCIceConnectionState? _iceConnectionState;
  RTCPeerConnectionState? _connectionState;

  @override
  RTCSignalingState? get signalingState => _signalingState;

  @override
  Future<RTCSignalingState?> getSignalingState() async {
    _signalingState = signalingStateForString(_jsPc.signalingState);
    return signalingState;
  }

  @override
  RTCIceGatheringState? get iceGatheringState => _iceGatheringState;

  @override
  Future<RTCIceGatheringState?> getIceGatheringState() async {
    _iceGatheringState = iceGatheringStateforString(_jsPc.iceGatheringState);
    return _iceGatheringState;
  }

  @override
  RTCIceConnectionState? get iceConnectionState => _iceConnectionState;

  @override
  Future<RTCIceConnectionState?> getIceConnectionState() async {
    _iceConnectionState = iceConnectionStateForString(_jsPc.iceConnectionState);
    if (browser.isFirefox) {
      switch (_iceConnectionState!) {
        case RTCIceConnectionState.RTCIceConnectionStateNew:
          _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateChecking:
          _connectionState =
              RTCPeerConnectionState.RTCPeerConnectionStateConnecting;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          _connectionState =
              RTCPeerConnectionState.RTCPeerConnectionStateConnected;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _connectionState =
              RTCPeerConnectionState.RTCPeerConnectionStateFailed;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _connectionState =
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _connectionState =
              RTCPeerConnectionState.RTCPeerConnectionStateClosed;
          break;
        default:
          break;
      }
    }
    return _iceConnectionState;
  }

  @override
  RTCPeerConnectionState? get connectionState => _connectionState;

  @override
  Future<RTCPeerConnectionState?> getConnectionState() async {
    if (browser.isFirefox) {
      await getIceConnectionState();
    } else {
      _connectionState = peerConnectionStateForString(_jsPc.connectionState);
    }
    return _connectionState;
  }

  @override
  Future<void> dispose() {
    _jsPc.close();
    return Future.value();
  }

  @override
  Map<String, dynamic> get getConfiguration => _configuration;

  @override
  Future<void> setConfiguration(Map<String, dynamic> configuration) {
    _configuration.addAll(configuration);

    _jsPc.setConfiguration(configuration.jsify() as html.RTCConfiguration);
    return Future.value();
  }

  @override
  Future<RTCSessionDescription> createOffer(
      [Map<String, dynamic>? constraints]) async {
    html.RTCSessionDescription desc;
    if (constraints != null) {
      final completer = Completer<html.RTCSessionDescription>();
      final successCb = (html.RTCSessionDescription description) {
        completer.complete(description);
      }.toJS;
      final errorCb = (JSObject error) {}.toJS;
      _jsPc.createOffer(
          successCb, errorCb, constraints.jsify() as html.RTCOfferOptions);
      desc = await completer.future;
    } else {
      desc = (await _jsPc.createOffer().toDart) as html.RTCSessionDescription;
    }

    return RTCSessionDescription(desc.sdp, desc.type);
  }

  @override
  Future<RTCSessionDescription> createAnswer(
      [Map<String, dynamic>? constraints]) async {
    if (constraints != null) {
      throw UnimplementedError(
          'createAnswer with constraints is not implemented');
    }
    html.RTCSessionDescription desc;

    desc = (await _jsPc.createAnswer().toDart) as html.RTCSessionDescription;

    return RTCSessionDescription(desc.sdp, desc.type);
  }

  @override
  Future<void> addStream(MediaStream stream) {
    throw UnimplementedError('addStream() is not implemented');
  }

  @override
  Future<void> removeStream(MediaStream stream) async {
    throw UnimplementedError('removeStream() is not implemented');
  }

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    await _jsPc
        .setLocalDescription(html.RTCLocalSessionDescriptionInit(
            sdp: description.sdp ?? '', type: description.type ?? ''))
        .toDart;
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _jsPc
        .setRemoteDescription(html.RTCSessionDescriptionInit(
            sdp: description.sdp ?? '', type: description.type ?? ''))
        .toDart;
  }

  @override
  Future<RTCSessionDescription?> getLocalDescription() async {
    if (null == _jsPc.localDescription) {
      return null;
    }

    return RTCSessionDescription(
      _jsPc.localDescription!.sdp,
      _jsPc.localDescription!.type,
    );
  }

  @override
  Future<RTCSessionDescription?> getRemoteDescription() async {
    if (null == _jsPc.remoteDescription) {
      return null;
    }
    return RTCSessionDescription(
      _jsPc.remoteDescription!.sdp,
      _jsPc.remoteDescription!.type,
    );
  }

  @override
  Future<void> addCandidate(RTCIceCandidate candidate) {
    return _jsPc
        .addIceCandidate((candidate.toMap() as Map<String, dynamic>).jsify()
            as html.RTCIceCandidateInit)
        .toDart;
  }

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async {
    html.RTCStatsReport stats;
    if (track != null) {
      var jsTrack = (track as MediaStreamTrackWeb).jsTrack;

      stats = await _jsPc.getStats(jsTrack).toDart as html.RTCStatsReport;
    } else {
      stats = await _jsPc.getStats().toDart as html.RTCStatsReport;
    }

    var report = <StatsReport>[];
    stats.forEach((JSObject stat) {
      final value = stat.dartify() as Map;
      report.add(
          StatsReport(value['id'], value['type'], value['timestamp'], value));
    }.toJS);
    return report;
  }

  @override
  List<MediaStream> getLocalStreams() =>
      _jsPc.getLocalStreams().toDart.map((stream) {
        final jsStream = stream as html.MediaStream;
        return _localStreams[jsStream.id]!;
      }).toList();

  @override
  List<MediaStream> getRemoteStreams() => _jsPc
      .getRemoteStreams()
      .toDart
      .map((jsStream) => _remoteStreams[(jsStream as html.MediaStream).id]!)
      .toList();

  @override
  Future<RTCDataChannel> createDataChannel(
      String label, RTCDataChannelInit dataChannelDict) {
    final map = dataChannelDict.toMap();
    if (dataChannelDict.binaryType == 'binary') {
      map['binaryType'] = 'arraybuffer'; // Avoid Blob in data channel
    }

    final jsDc =
        _jsPc.createDataChannel(label, map.jsify() as html.RTCDataChannelInit);
    return Future.value(RTCDataChannelWeb(jsDc));
  }

  @override
  Future<void> restartIce() {
    _jsPc.restartIce();
    return Future.value();
  }

  @override
  Future<void> close() async {
    _jsPc.close();
    return Future.value();
  }

  @override
  RTCDTMFSender createDtmfSender(MediaStreamTrack track) {
    final _native = track as MediaStreamTrackWeb;
    final jsDtmfSender = _jsPc.createDTMFSender(_native.jsTrack);
    return RTCDTMFSenderWeb(jsDtmfSender);
  }

  @override
  Future<RTCRtpSender> addTrack(MediaStreamTrack track,
      [MediaStream? stream]) async {
    final jStream = (stream as MediaStreamWeb).jsStream;
    final jsTrack = (track as MediaStreamTrackWeb).jsTrack;
    final sender = _jsPc.addTrack(jsTrack, jStream);
    return RTCRtpSenderWeb(sender, sender.track != null);
  }

  @override
  Future<bool> removeTrack(RTCRtpSender sender) async {
    final nativeSender = sender as RTCRtpSenderWeb;
    // var nativeTrack = nativeSender.track as MediaStreamTrackWeb;
    _jsPc.removeTrack(nativeSender.jsRtpSender);
    return Future<bool>.value(true);
  }

  @override
  Future<List<RTCRtpSender>> getSenders() async {
    final senders = _jsPc.getSenders();
    final list = <RTCRtpSender>[];
    senders.toDart.forEach((e) {
      list.add(RTCRtpSenderWeb.fromJsSender(e as html.RTCRtpSender));
    });
    return list;
  }

  @override
  Future<List<RTCRtpReceiver>> getReceivers() async {
    final receivers = _jsPc.getReceivers();

    final list = <RTCRtpReceiver>[];
    receivers.toDart.forEach((e) {
      list.add(RTCRtpReceiverWeb(e as html.RTCRtpReceiver));
    });

    return list;
  }

  @override
  Future<List<RTCRtpTransceiver>> getTransceivers() async {
    final transceivers = _jsPc.getTransceivers();

    final list = <RTCRtpTransceiver>[];
    transceivers.toDart.forEach((e) {
      list.add(RTCRtpTransceiverWeb.fromJsObject(
        e as html.RTCRtpTransceiver,
      ));
    });

    return list;
  }

  //'audio|video', { 'direction': 'recvonly|sendonly|sendrecv' }
  //
  // https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/addTransceiver
  //
  @override
  Future<RTCRtpTransceiver> addTransceiver({
    MediaStreamTrack? track,
    RTCRtpMediaType? kind,
    RTCRtpTransceiverInit? init,
  }) async {
    final jsTrack = track is MediaStreamTrackWeb ? track.jsTrack : null;
    final kindString = kind != null ? typeRTCRtpMediaTypetoString[kind] : null;
    final trackOrKind = jsTrack ?? kindString;
    assert(trackOrKind != null, 'track or kind must not be null');

    html.RTCRtpTransceiver transceiver;
    if (init == null) {
      transceiver = _jsPc.addTransceiver(
        trackOrKind.jsify()!,
      );
    } else {
      final sendEncodings = JSArray();
      init.sendEncodings?.forEach((element) {
        sendEncodings.toDart.add(element.toMap().jsify());
      });
      final streams = JSArray();
      init.streams?.forEach((element) {
        streams.toDart.add((element as MediaStreamWeb).jsStream.jsify());
      });
      transceiver = _jsPc.addTransceiver(
          trackOrKind.jsify()!,
          html.RTCRtpTransceiverInit(
              direction: typeRtpTransceiverDirectionToString[init.direction] ??
                  'sendrecv',
              sendEncodings: sendEncodings,
              streams: streams));
    }

    return RTCRtpTransceiverWeb.fromJsObject(
      transceiver,
      peerConnectionId: _peerConnectionId,
    );
  }
}

extension GetStreamsExt on html.RTCPeerConnection {
  external JSArray getLocalStreams();
  external JSArray getRemoteStreams();
  external html.RTCDTMFSender createDTMFSender(html.MediaStreamTrack track);
}
