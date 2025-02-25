import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/helpers.dart' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

class RTCDataChannelWeb extends RTCDataChannel {
  RTCDataChannelWeb(this._jsDc) {
    stateChangeStream = _stateChangeController.stream;
    messageStream = _messageController.stream;
    _jsDc.onclose = (html.Event _) {
      _state = RTCDataChannelState.RTCDataChannelClosed;
      _stateChangeController.add(_state);
      onDataChannelState?.call(_state);
    }.toJS;

    _jsDc.onopen = (html.Event _) {
      _state = RTCDataChannelState.RTCDataChannelOpen;
      _stateChangeController.add(_state);
      onDataChannelState?.call(_state);
    }.toJS;

    _jsDc.onmessage = (html.MessageEvent event) async {
      var msg = await _parse(event.data);
      _messageController.add(msg);
      onMessage?.call(msg);
    }.toJS;

    _jsDc.onbufferedamountlow = (html.Event _) {
      onBufferedAmountLow?.call(bufferedAmount ?? 0);
    }.toJS;
  }

  final html.RTCDataChannel _jsDc;
  RTCDataChannelState _state = RTCDataChannelState.RTCDataChannelConnecting;

  @override
  RTCDataChannelState get state => _state;

  @override
  int? get id => _jsDc.id;

  @override
  String? get label => _jsDc.label;

  @override
  int? get bufferedAmount => _jsDc.bufferedAmount;

  @override
  set bufferedAmountLowThreshold(int? bufferedAmountLowThreshold) {
    _jsDc.bufferedAmountLowThreshold = bufferedAmountLowThreshold ?? 0;
  }

  final _stateChangeController =
      StreamController<RTCDataChannelState>.broadcast(sync: true);
  final _messageController =
      StreamController<RTCDataChannelMessage>.broadcast(sync: true);

  Future<RTCDataChannelMessage> _parse(dynamic data) async {
    if (data is String) return RTCDataChannelMessage(data);
    if (data is html.Blob) {
      // This should never happen actually
      final arrayBuffer = (await data.arrayBuffer().toDart) as ByteBuffer;
      return RTCDataChannelMessage.fromBinary(arrayBuffer.asUint8List());
    } else if (data is ByteBuffer) {
      var arrayBuffer = data;
      return RTCDataChannelMessage.fromBinary(arrayBuffer.asUint8List());
    } else {
      throw Exception('Unknown data type: ${data.runtimeType}');
    }
  }

  @override
  Future<void> send(RTCDataChannelMessage message) {
    if (!message.isBinary) {
      _jsDc.send(message.text.toJS);
    } else {
      _jsDc.send(message.binary.toJS);
    }
    return Future.value();
  }

  @override
  Future<void> close() {
    _jsDc.close();
    return Future.value();
  }
}
