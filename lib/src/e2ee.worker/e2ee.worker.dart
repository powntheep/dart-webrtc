import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:js/js.dart';

import 'e2ee.cryptor.dart';

@JS('WritableStream')
abstract class WritableStream {
  external void abort();
  external void close();
  external bool locked();
  external WritableStream clone();
}

@JS('ReadableStream')
abstract class ReadableStream {
  external void cancel();
  external bool locked();
  external ReadableStream pipeThrough(dynamic transformStream);
  external void pipeTo(WritableStream writableStream);
  external ReadableStream clone();
}

@JS('TransformStream')
class TransformStream {
  external TransformStream(dynamic);
  external ReadableStream get readable;
  external WritableStream get writable;
}

@anonymous
@JS()
abstract class TransformStreamDefaultController {
  external void enqueue(dynamic chunk);
  external void error(dynamic error);
  external void terminate();
}

@anonymous
@JS()
class EncodedStreams {
  external ReadableStream get readable;
  external WritableStream get writable;
}

@JS()
class RTCEncodedFrame {
  external int get timestamp;
  external ByteBuffer get data;
  external set data(ByteBuffer data);
  external RTCEncodedFrameMetadata getMetadata();
  external String? get type;
}

@JS()
class RTCEncodedAudioFrame {
  external int get timestamp;
  external ByteBuffer get data;
  external set data(ByteBuffer data);
  external int? get size;
  external RTCEncodedAudioFrameMetadata getMetadata();
}

@JS()
class RTCEncodedVideoFrame {
  external int get timestamp;
  external ByteBuffer get data;
  external set data(ByteBuffer data);
  external String get type;
  external RTCEncodedVideoFrameMetadata getMetadata();
}

@JS()
class RTCEncodedFrameMetadata {
  external int get payloadType;
  external int get synchronizationSource;
}

@JS()
class RTCEncodedAudioFrameMetadata {
  external int get payloadType;
  external int get synchronizationSource;
}

@JS()
class RTCEncodedVideoFrameMetadata {
  external int get frameId;
  external int get width;
  external int get height;
  external int get payloadType;
  external int get synchronizationSource;
}

@JS('RTCTransformEvent')
class RTCTransformEvent {
  external factory RTCTransformEvent();
}

extension PropsRTCTransformEvent on RTCTransformEvent {
  RTCRtpScriptTransformer get transformer =>
      js_util.getProperty(this, 'transformer');
}

@JS()
@staticInterop
class RTCRtpScriptTransformer {
  external factory RTCRtpScriptTransformer();
}

extension PropsRTCRtpScriptTransformer on RTCRtpScriptTransformer {
  ReadableStream get readable => js_util.getProperty(this, 'readable');
  WritableStream get writable => js_util.getProperty(this, 'writable');
  dynamic get options => js_util.getProperty(this, 'options');
  Future<int> generateKeyFrame([String? rid]) => js_util
      .promiseToFuture(js_util.callMethod(this, 'generateKeyFrame', [rid]));

  Future<void> sendKeyFrameRequest() => js_util
      .promiseToFuture(js_util.callMethod(this, 'sendKeyFrameRequest', []));

  set handled(bool value) {
    js_util.setProperty(this, 'handled', value);
  }
}

@JS('RTCRtpScriptTransform')
class RTCRtpScriptTransform {
  external factory RTCRtpScriptTransform(html.Worker worker,
      [dynamic options, Iterable<dynamic>? transfer]);
}

@anonymous
@JS()
class EnableTransformMessage {
  external factory EnableTransformMessage({
    ReadableStream readable,
    WritableStream writable,
    String msgType,
    String kind,
    String participantId,
    String trackId,
    String codec,
  });
  external ReadableStream get readable;
  external WritableStream get writable;
  external String get msgType; // 'encode' or 'decode'
  external String get participantId;
  external String get trackId;
  external String get kind;
  external String get codec;
}

@anonymous
@JS()
class RemoveTransformMessage {
  external factory RemoveTransformMessage(
      {String msgType, String participantId, String trackId});
  external String get msgType; // 'removeTransform'
  external String get participantId;
  external String get trackId;
}

@JS('self')
external html.DedicatedWorkerGlobalScope get self;

extension PropsRTCTransformEventHandler on html.DedicatedWorkerGlobalScope {
  set onrtctransform(Function(dynamic) callback) =>
      js_util.setProperty<Function>(this, 'onrtctransform', callback);
}

var participantCryptors = <FrameCryptor>[];
var publisherKeys = <String, html.CryptoKey>{};
bool isEncryptionEnabled = false;

KeyOptions keyProviderOptions = KeyOptions(
    sharedKey: true,
    ratchetSalt: Uint8List.fromList('ratchetSalt'.codeUnits),
    ratchetWindowSize: 16);

void main() async {
  print('E2EE Worker created');

  if (js_util.getProperty(self, 'RTCTransformEvent') != null) {
    print('setup transform event handler');
    self.onrtctransform = allowInterop((event) {
      print('got transform event');
      var transformer = (event as RTCTransformEvent).transformer;
      transformer.handled = true;
      var options = transformer.options;
      var kind = options.kind;
      var participantId = options.participantId;
      var trackId = options.trackId;
      var codec = options.codec;
      var msgType = options.msgType;

      var cryptor =
          participantCryptors.firstWhereOrNull((c) => c.trackId == trackId);

      if (cryptor == null) {
        cryptor = FrameCryptor(
          worker: self,
          participantId: participantId,
          trackId: trackId,
          keyOptions: keyProviderOptions,
        );
        participantCryptors.add(cryptor);
      }

      cryptor.setupTransform(
          operation: msgType,
          readable: transformer.readable,
          writable: transformer.writable,
          trackId: trackId,
          kind: kind,
          codec: codec);
    });
  }

  self.onMessage.listen((e) {
    var msg = e.data;
    var msgType = msg['msgType'];
    switch (msgType) {
      case 'init':
        var options = msg['keyOptions'];
        keyProviderOptions = KeyOptions(
            sharedKey: options['sharedKey'],
            ratchetSalt: Uint8List.fromList(
                base64Decode(options['ratchetSalt'] as String)),
            ratchetWindowSize: options['ratchetWindowSize'],
            uncryptedMagicBytes: options['ratchetSalt'] != null
                ? Uint8List.fromList(
                    base64Decode(options['uncryptedMagicBytes'] as String))
                : null);
        print('worker: init with keyOptions ${keyProviderOptions.toString()}');
        break;
      case 'enable':
        {
          var enabled = msg['enabled'] as bool;
          var participantId = msg['participantId'] as String;
          print('worker: set enable $enabled for participantId $participantId');
          var cryptors = participantCryptors
              .where((c) => c.participantId == participantId)
              .toList();
          for (var cryptor in cryptors) {
            cryptor.setEnabled(enabled);
          }
          self.postMessage({
            'type': 'cryptorEnabled',
            'participantId': participantId,
            'enable': enabled,
          });
        }
        break;
      case 'decode':
      case 'encode':
        {
          var kind = msg['kind'];
          var exist = msg['exist'] as bool;
          var participantId = msg['participantId'] as String;
          var trackId = msg['trackId'];
          var readable = msg['readableStream'] as ReadableStream;
          var writable = msg['writableStream'] as WritableStream;

          print(
              'worker: got $msgType, kind $kind, trackId $trackId, participantId $participantId, ${readable.runtimeType} ${writable.runtimeType}}');
          var cryptor =
              participantCryptors.firstWhereOrNull((c) => c.trackId == trackId);

          if (cryptor == null) {
            cryptor = FrameCryptor(
                worker: self,
                participantId: participantId,
                trackId: trackId,
                keyOptions: keyProviderOptions);
            participantCryptors.add(cryptor);
          }

          if (!exist) {
            cryptor.setupTransform(
                operation: msgType,
                readable: readable,
                writable: writable,
                trackId: trackId,
                kind: kind);
          }
          cryptor.setParticipantId(participantId);
          self.postMessage({
            'type': 'cryptorSetup',
            'participantId': participantId,
            'trackId': trackId,
            'exist': exist,
            'operation': msgType,
          });
          cryptor.lastError = CryptorError.kNew;
        }
        break;
      case 'removeTransform':
        {
          var trackId = msg['trackId'] as String;
          print('worker: removing trackId $trackId');
          participantCryptors.removeWhere((c) => c.trackId == trackId);
        }
        break;
      case 'setKey':
        {
          var key = Uint8List.fromList(base64Decode(msg['key'] as String));
          var keyIndex = msg['keyIndex'];
          //print('worker: got setKey ${msg['key']}, key $key');
          var participantId = msg['participantId'] as String;
          print('worker: setup key for participant $participantId');

          if (keyProviderOptions.sharedKey) {
            for (var c in participantCryptors) {
              c.setKey(keyIndex, key);
            }
            return;
          }
          var cryptors = participantCryptors
              .where((c) => c.participantId == participantId)
              .toList();
          for (var c in cryptors) {
            c.setKey(keyIndex, key);
          }
        }
        break;
      case 'setSharedKey':
        {
          var key = Uint8List.fromList(base64Decode(msg['key'] as String));
          var keyIndex = msg['keyIndex'];
          if (keyProviderOptions.sharedKey) {
            for (var c in participantCryptors) {
              c.setKey(keyIndex, key);
            }
            return;
          }
        }
        break;
      case 'ratchetKey':
        {
          var keyIndex = msg['keyIndex'];
          var participantId = msg['participantId'] as String;
          print(
              'worker: ratchetKey for participant $participantId, keyIndex $keyIndex');
          var cryptors = participantCryptors
              .where((c) => c.participantId == participantId)
              .toList();
          for (var c in cryptors) {
            var keySet = c.getKeySet(keyIndex);
            c.ratchetKey(keyIndex).then((_) async {
              var newKey = await c.ratchet(
                  keySet!.material, keyProviderOptions.ratchetSalt);
              self.postMessage({
                'type': 'ratchetKey',
                'participantId': participantId,
                'trackId': c.trackId,
                'key': base64Encode(newKey),
              });
            });
          }
        }
        break;
      case 'ratchetSharedKey':
        {
          var keyIndex = msg['keyIndex'];
          for (var c in participantCryptors) {
            var keySet = c.getKeySet(keyIndex);
            c.ratchetKey(keyIndex).then((_) async {
              await c.ratchet(keySet!.material, keyProviderOptions.ratchetSalt);
            });
          }
        }
        break;
      case 'setKeyIndex':
        {
          var keyIndex = msg['index'];
          var participantId = msg['participantId'] as String;
          print('worker: setup key index for participant $participantId');
          var cryptors = participantCryptors
              .where((c) => c.participantId == participantId)
              .toList();
          for (var c in cryptors) {
            c.setKeyIndex(keyIndex);
          }
        }
        break;
      case 'setSifTrailer':
        {
          var sifTrailer =
              Uint8List.fromList(base64Decode(msg['sifTrailer'] as String));
          keyProviderOptions.uncryptedMagicBytes = sifTrailer;
          for (var c in participantCryptors) {
            c.keyOptions.uncryptedMagicBytes = sifTrailer;
          }
        }
        break;
      case 'updateCodec':
        {
          var codec = msg['codec'] as String;
          var trackId = msg['trackId'] as String;
          print('worker: update codec for trackId $trackId, codec $codec');
          var cryptor =
              participantCryptors.firstWhereOrNull((c) => c.trackId == trackId);
          cryptor?.updateCodec(codec);
        }
        break;
      case 'dispose':
        {
          var trackId = msg['trackId'] as String;
          print('worker: dispose trackId $trackId');
          var cryptor =
              participantCryptors.firstWhereOrNull((c) => c.trackId == trackId);
          if (cryptor != null) {
            cryptor.lastError = CryptorError.kDisposed;
            self.postMessage({
              'type': 'cryptorDispose',
              'participantId': cryptor.participantId,
              'trackId': trackId,
            });
          }
        }
        break;
      default:
        print('worker: unknown message kind $msg');
    }
  });
}
