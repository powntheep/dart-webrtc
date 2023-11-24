import 'dart:async';
import 'dart:convert';
import 'dart:js';
import 'dart:js_interop';
import 'dart:js_util';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:web/helpers.dart' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'rtc_rtp_receiver_impl.dart';
import 'rtc_rtp_sender_impl.dart';

extension RtcRtpReceiverExt on html.RTCRtpReceiver {
  static Map<int, html.ReadableStream> readableStreams_ = {};
  static Map<int, html.WritableStream> writableStreams_ = {};

  html.ReadableStream? get readable {
    if (readableStreams_.containsKey(hashCode)) {
      return readableStreams_[hashCode]!;
    }
    return null;
  }

  html.WritableStream? get writable {
    if (writableStreams_.containsKey(hashCode)) {
      return writableStreams_[hashCode]!;
    }
    return null;
  }

  set readableStream(html.ReadableStream stream) {
    readableStreams_[hashCode] = stream;
  }

  set writableStream(html.WritableStream stream) {
    writableStreams_[hashCode] = stream;
  }

  void closeStreams() {
    readableStreams_.remove(hashCode);
    writableStreams_.remove(hashCode);
  }
}

extension RtcRtpSenderExt on html.RTCRtpSender {
  static Map<int, html.ReadableStream> readableStreams_ = {};
  static Map<int, html.WritableStream> writableStreams_ = {};

  html.ReadableStream? get readable {
    if (readableStreams_.containsKey(hashCode)) {
      return readableStreams_[hashCode]!;
    }
    return null;
  }

  html.WritableStream? get writable {
    if (writableStreams_.containsKey(hashCode)) {
      return writableStreams_[hashCode]!;
    }
    return null;
  }

  set readableStream(html.ReadableStream stream) {
    readableStreams_[hashCode] = stream;
  }

  set writableStream(html.WritableStream stream) {
    writableStreams_[hashCode] = stream;
  }

  void closeStreams() {
    readableStreams_.remove(hashCode);
    writableStreams_.remove(hashCode);
  }
}

class FrameCryptorImpl extends FrameCryptor {
  FrameCryptorImpl(
      this._factory, this.worker, this._participantId, this._trackId,
      {this.jsSender, this.jsReceiver, required this.keyProvider});
  html.Worker worker;
  bool _enabled = false;
  int _keyIndex = 0;
  final String _participantId;
  final String _trackId;
  final html.RTCRtpSender? jsSender;
  final html.RTCRtpReceiver? jsReceiver;
  final FrameCryptorFactoryImpl _factory;
  final KeyProviderImpl keyProvider;

  @override
  Future<void> dispose() async {
    worker.postMessage({
      'msgType': 'dispose',
      'trackId': _trackId,
    }.jsify());

    _factory.removeFrameCryptor(_trackId);
    return;
  }

  @override
  Future<bool> get enabled => Future(() => _enabled);

  @override
  Future<int> get keyIndex => Future(() => _keyIndex);

  @override
  String get participantId => _participantId;

  String get trackId => _trackId;

  @override
  Future<bool> setEnabled(bool enabled) async {
    worker.postMessage({
      'msgType': 'enable',
      'participantId': participantId,
      'enabled': enabled
    }.jsify());

    _enabled = enabled;
    return true;
  }

  @override
  Future<bool> setKeyIndex(int index) async {
    worker.postMessage({
      'msgType': 'setKeyIndex',
      'participantId': participantId,
      'index': index,
    }.jsify());

    _keyIndex = index;
    return true;
  }

  @override
  Future<void> updateCodec(String codec) async {
    worker.postMessage({
      'msgType': 'updateCodec',
      'trackId': _trackId,
      'codec': codec,
    }.jsify());
  }
}

class KeyProviderImpl implements KeyProvider {
  KeyProviderImpl(this._id, this.worker, this.options);
  final String _id;
  final html.Worker worker;
  final KeyProviderOptions options;
  final Map<String, List<Uint8List>> _keys = {};

  @override
  String get id => _id;

  Future<void> init() async {
    worker.postMessage({
      'msgType': 'init',
      'id': id,
      'keyOptions': {
        'sharedKey': options.sharedKey,
        'ratchetSalt': base64Encode(options.ratchetSalt),
        'ratchetWindowSize': options.ratchetWindowSize,
        if (options.uncryptedMagicBytes != null)
          'uncryptedMagicBytes': base64Encode(options.uncryptedMagicBytes!),
      },
    }.jsify());
  }

  @override
  Future<void> dispose() {
    return Future.value();
  }

  @override
  Future<bool> setKey(
      {required String participantId,
      required int index,
      required Uint8List key}) async {
    worker.postMessage({
      'msgType': 'setKey',
      'participantId': participantId,
      'keyIndex': index,
      'key': base64Encode(key),
    }.jsify());

    _keys[participantId] ??= [];
    if (_keys[participantId]!.length <= index) {
      _keys[participantId]!.add(key);
    } else {
      _keys[participantId]![index] = key;
    }
    return true;
  }

  Completer<Uint8List>? _ratchetKeyCompleter;

  void onRatchetKey(Uint8List key) {
    if (_ratchetKeyCompleter != null) {
      _ratchetKeyCompleter!.complete(key);
      _ratchetKeyCompleter = null;
    }
  }

  @override
  Future<Uint8List> ratchetKey(
      {required String participantId, required int index}) async {
    worker.postMessage({
      'msgType': 'ratchetKey',
      'participantId': participantId,
      'keyIndex': index,
    }.jsify());

    _ratchetKeyCompleter ??= Completer();

    return _ratchetKeyCompleter!.future;
  }

  @override
  Future<Uint8List> exportKey(
      {required String participantId, required int index}) {
    throw UnimplementedError('exportKey not supported for web');
  }

  @override
  Future<Uint8List> exportSharedKey({int index = 0}) {
    throw UnimplementedError('exportSharedKey not supported for web');
  }

  @override
  Future<Uint8List> ratchetSharedKey({int index = 0}) async {
    worker.postMessage({
      'msgType': 'ratchetSharedKey',
      'keyIndex': index,
    }.jsify());
    return Uint8List(0);
  }

  @override
  Future<void> setSharedKey({required Uint8List key, int index = 0}) async {
    worker.postMessage({
      'msgType': 'setSharedKey',
      'keyIndex': index,
      'key': base64Encode(key),
    }.jsify());
  }

  @override
  Future<void> setSifTrailer({required Uint8List trailer}) async {
    worker.postMessage({
      'msgType': 'setSifTrailer',
      'sifTrailer': base64Encode(trailer),
    }.jsify());
  }
}

class FrameCryptorFactoryImpl implements FrameCryptorFactory {
  FrameCryptorFactoryImpl._internal() {
    worker = html.Worker('e2ee.worker.dart.js');
    worker.onmessage = ((html.MessageEvent msg) {
      print('master got ${msg.data}');
      final data = msg.data.dartify() as Map<String, dynamic>;
      var type = data['type'];
      if (type == 'cryptorState') {
        var trackId = data['trackId'];
        var participantId = data['participantId'];
        var frameCryptor = _frameCryptors.values.firstWhereOrNull(
            (element) => (element as FrameCryptorImpl).trackId == trackId);
        var state = data['state'];
        var frameCryptorState = FrameCryptorState.FrameCryptorStateNew;
        switch (state) {
          case 'ok':
            frameCryptorState = FrameCryptorState.FrameCryptorStateOk;
            break;
          case 'decryptError':
            frameCryptorState =
                FrameCryptorState.FrameCryptorStateDecryptionFailed;
            break;
          case 'encryptError':
            frameCryptorState =
                FrameCryptorState.FrameCryptorStateEncryptionFailed;
            break;
          case 'missingKey':
            frameCryptorState = FrameCryptorState.FrameCryptorStateMissingKey;
            break;
          case 'internalError':
            frameCryptorState =
                FrameCryptorState.FrameCryptorStateInternalError;
            break;
          case 'keyRatcheted':
            frameCryptorState = FrameCryptorState.FrameCryptorStateKeyRatcheted;
            break;
        }
        frameCryptor?.onFrameCryptorStateChanged
            ?.call(participantId, frameCryptorState);
      } else if (type == 'ratchetKey') {
        var trackId = data['trackId'];
        var frameCryptor = _frameCryptors.values.firstWhereOrNull(
            (element) => (element as FrameCryptorImpl).trackId == trackId);
        if (frameCryptor != null) {
          (frameCryptor as FrameCryptorImpl)
              .keyProvider
              .onRatchetKey(base64Decode(data['key']));
        }
      }
    }).toJS;
    worker.onerror = ((html.Event err) {
      print('worker error: $err');
    }).toJS;
  }

  static final FrameCryptorFactoryImpl instance =
      FrameCryptorFactoryImpl._internal();

  late html.Worker worker;
  final Map<String, FrameCryptor> _frameCryptors = {};

  @override
  Future<KeyProvider> createDefaultKeyProvider(
      KeyProviderOptions options) async {
    var keyProvider = KeyProviderImpl('default', worker, options);
    await keyProvider.init();
    return keyProvider;
  }

  @override
  Future<FrameCryptor> createFrameCryptorForRtpReceiver(
      {required String participantId,
      required RTCRtpReceiver receiver,
      required Algorithm algorithm,
      required KeyProvider keyProvider}) {
    var jsReceiver = (receiver as RTCRtpReceiverWeb).jsRtpReceiver;

    var trackId = jsReceiver.hashCode.toString();
    var kind = jsReceiver.track.kind;

    if (context['RTCRtpScriptTransform'] != null) {
      print('support RTCRtpScriptTransform');
      var options = {
        'msgType': 'decode',
        'kind': kind,
        'participantId': participantId,
        'trackId': trackId,
      };
      jsReceiver.transform =
          html.RTCRtpScriptTransform(worker, options.jsify()) as JSObject;
    } else {
      throw UnimplementedError(
          'createEncodedStreams is not implemented');
    }
    FrameCryptor cryptor = FrameCryptorImpl(
        this, worker, participantId, trackId,
        jsReceiver: jsReceiver, keyProvider: keyProvider as KeyProviderImpl);
    _frameCryptors[trackId] = cryptor;
    return Future.value(cryptor);
  }

  @override
  Future<FrameCryptor> createFrameCryptorForRtpSender(
      {required String participantId,
      required RTCRtpSender sender,
      required Algorithm algorithm,
      required KeyProvider keyProvider}) {
    var jsSender = (sender as RTCRtpSenderWeb).jsRtpSender;
    var trackId = jsSender.hashCode.toString();
    var kind = jsSender.track!.kind;

    if (context['RTCRtpScriptTransform'] != null) {
      print('support RTCRtpScriptTransform');
      var options = {
        'msgType': 'encode',
        'kind': kind,
        'participantId': participantId,
        'trackId': trackId,
        'options': (keyProvider as KeyProviderImpl).options.toJson(),
      };
      jsSender.transform =
          html.RTCRtpScriptTransform(worker, options.jsify()) as JSObject;
    } else {
      throw UnimplementedError(
          'createEncodedStreams is not implemented');
    }
    FrameCryptor cryptor = FrameCryptorImpl(
        this, worker, participantId, trackId,
        jsSender: jsSender, keyProvider: keyProvider);
    _frameCryptors[trackId] = cryptor;
    return Future.value(cryptor);
  }

  void removeFrameCryptor(String trackId) {
    _frameCryptors.remove(trackId);
  }
}
