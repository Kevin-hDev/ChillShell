import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' as pc;

class KeyGenerationService {
  static const _sshEd25519KeyType = 'ssh-ed25519';

  // SECURITY NOTE: Les clés Ed25519 sont générées sans chiffrement par passphrase
  // (cipher=none, kdf=none). Acceptable car elles ne quittent jamais le secure
  // storage (Android Keystore / iOS Keychain). Si export utilisateur ajouté,
  // implémenter chiffrement AES-256-CTR + bcrypt KDF (RFC 4880).

  /// Génère une paire de clés Ed25519
  static Future<Map<String, String>> generateEd25519(String comment) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();

    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    // Formatter en format OpenSSH
    final privateKeyPem = _formatEd25519PrivateKey(
      privateKeyBytes,
      publicKey.bytes,
    );
    final publicKeyOpenSSH = _formatEd25519PublicKey(publicKey.bytes, comment);

    // SECURITY NOTE: Zero out private key bytes after formatting to PEM.
    // Prevents sensitive key material from lingering in memory.
    for (var i = 0; i < privateKeyBytes.length; i++) {
      privateKeyBytes[i] = 0;
    }

    return {'privateKey': privateKeyPem, 'publicKey': publicKeyOpenSSH};
  }

  /// Génère une paire de clés RSA 4096 bits
  static Future<Map<String, String>> generateRSA4096(String comment) async {
    final keyGen = pc.RSAKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 4096, 64),
          _secureRandom(),
        ),
      );

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as pc.RSAPublicKey;
    final privateKey = pair.privateKey as pc.RSAPrivateKey;

    final privateKeyPem = _formatRSAPrivateKey(privateKey);
    final publicKeyOpenSSH = _formatRSAPublicKey(publicKey, comment);

    return {'privateKey': privateKeyPem, 'publicKey': publicKeyOpenSSH};
  }

  static pc.SecureRandom _secureRandom() {
    final secureRandom = pc.FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  static String _formatEd25519PrivateKey(
    List<int> privateBytes,
    List<int> publicBytes,
  ) {
    final buffer = BytesBuilder();

    // AUTH_MAGIC
    buffer.add(utf8.encode('openssh-key-v1'));
    buffer.addByte(0);

    // cipher, kdf, kdf options (none = unencrypted)
    _writeString(buffer, 'none');
    _writeString(buffer, 'none');
    _writeInt32(buffer, 0);

    // number of keys
    _writeInt32(buffer, 1);

    // public key
    final pubKeyBuffer = BytesBuilder();
    _writeString(pubKeyBuffer, _sshEd25519KeyType);
    _writeBytes(pubKeyBuffer, Uint8List.fromList(publicBytes));
    _writeBytes(buffer, pubKeyBuffer.toBytes());

    // private key section
    final privKeyBuffer = BytesBuilder();
    final checkInt = Random.secure().nextInt(0xFFFFFFFF);
    _writeInt32(privKeyBuffer, checkInt);
    _writeInt32(privKeyBuffer, checkInt);
    _writeString(privKeyBuffer, _sshEd25519KeyType);
    _writeBytes(privKeyBuffer, Uint8List.fromList(publicBytes));
    _writeBytes(
      privKeyBuffer,
      Uint8List.fromList([...privateBytes, ...publicBytes]),
    );
    _writeString(privKeyBuffer, '');

    // Padding
    var privData = privKeyBuffer.toBytes();
    final padLength = (8 - (privData.length % 8)) % 8;
    if (padLength > 0) {
      final padding = List<int>.generate(padLength, (i) => i + 1);
      final paddedBuffer = BytesBuilder();
      paddedBuffer.add(privData);
      paddedBuffer.add(padding);
      privData = paddedBuffer.toBytes();
    }

    _writeBytes(buffer, privData);

    final keyData = base64.encode(buffer.toBytes());
    final lines = <String>[];
    for (var i = 0; i < keyData.length; i += 70) {
      lines.add(
        keyData.substring(i, i + 70 > keyData.length ? keyData.length : i + 70),
      );
    }

    return '-----BEGIN OPENSSH PRIVATE KEY-----\n${lines.join('\n')}\n-----END OPENSSH PRIVATE KEY-----';
  }

  static String _formatEd25519PublicKey(List<int> publicBytes, String comment) {
    final buffer = BytesBuilder();
    _writeString(buffer, _sshEd25519KeyType);
    _writeBytes(buffer, Uint8List.fromList(publicBytes));
    return '$_sshEd25519KeyType ${base64.encode(buffer.toBytes())} $comment';
  }

  static String _formatRSAPrivateKey(pc.RSAPrivateKey privateKey) {
    final encoded = _encodeRSAPrivateKey(privateKey);
    final keyData = base64.encode(encoded);
    final lines = <String>[];
    for (var i = 0; i < keyData.length; i += 64) {
      lines.add(
        keyData.substring(i, i + 64 > keyData.length ? keyData.length : i + 64),
      );
    }
    return '-----BEGIN RSA PRIVATE KEY-----\n${lines.join('\n')}\n-----END RSA PRIVATE KEY-----';
  }

  static Uint8List _encodeRSAPrivateKey(pc.RSAPrivateKey key) {
    final sequence = <Uint8List>[];
    sequence.add(_encodeInteger(BigInt.zero));
    sequence.add(_encodeInteger(key.modulus!));
    sequence.add(_encodeInteger(key.publicExponent!));
    sequence.add(_encodeInteger(key.privateExponent!));
    sequence.add(_encodeInteger(key.p!));
    sequence.add(_encodeInteger(key.q!));
    sequence.add(_encodeInteger(key.privateExponent! % (key.p! - BigInt.one)));
    sequence.add(_encodeInteger(key.privateExponent! % (key.q! - BigInt.one)));
    sequence.add(_encodeInteger(key.q!.modInverse(key.p!)));

    final content = BytesBuilder();
    for (final item in sequence) {
      content.add(item);
    }

    return _encodeSequence(content.toBytes());
  }

  static String _formatRSAPublicKey(pc.RSAPublicKey publicKey, String comment) {
    final buffer = BytesBuilder();
    _writeString(buffer, 'ssh-rsa');
    _writeMPInt(buffer, publicKey.publicExponent!);
    _writeMPInt(buffer, publicKey.modulus!);
    return 'ssh-rsa ${base64.encode(buffer.toBytes())} $comment';
  }

  static void _writeString(BytesBuilder buffer, String value) {
    final bytes = utf8.encode(value);
    _writeInt32(buffer, bytes.length);
    buffer.add(bytes);
  }

  static void _writeBytes(BytesBuilder buffer, Uint8List bytes) {
    _writeInt32(buffer, bytes.length);
    buffer.add(bytes);
  }

  static void _writeInt32(BytesBuilder buffer, int value) {
    buffer.add([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  static void _writeMPInt(BytesBuilder buffer, BigInt value) {
    var bytes = _bigIntToBytes(value);
    if (bytes.isNotEmpty && bytes[0] & 0x80 != 0) {
      bytes = Uint8List.fromList([0, ...bytes]);
    }
    _writeBytes(buffer, bytes);
  }

  static Uint8List _bigIntToBytes(BigInt value) {
    var hex = value.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  static Uint8List _encodeInteger(BigInt value) {
    var bytes = _bigIntToBytes(value);
    if (bytes.isEmpty) bytes = Uint8List.fromList([0]);
    if (bytes[0] & 0x80 != 0) {
      bytes = Uint8List.fromList([0, ...bytes]);
    }
    return _encodeTLV(0x02, bytes);
  }

  static Uint8List _encodeSequence(Uint8List content) {
    return _encodeTLV(0x30, content);
  }

  static Uint8List _encodeTLV(int tag, Uint8List value) {
    final buffer = BytesBuilder();
    buffer.addByte(tag);
    if (value.length < 128) {
      buffer.addByte(value.length);
    } else if (value.length < 256) {
      buffer.addByte(0x81);
      buffer.addByte(value.length);
    } else {
      buffer.addByte(0x82);
      buffer.addByte((value.length >> 8) & 0xFF);
      buffer.addByte(value.length & 0xFF);
    }
    buffer.add(value);
    return buffer.toBytes();
  }
}
