import 'package:encrypt/encrypt.dart' as x;
import 'dart:convert' show utf8;
import 'package:convert/convert.dart' show hex;

/// An encapsulation of the cryptography required to interface with XBee.
///
/// Algorithm is AES-256-CTR.
class XBeeEncrypter {
  x.Encrypter xx;

  String txNonce; // hex string
  int txByteCtr = 0;
  int txCtr = 1;

  String rxNonce; // hex string
  int rxByteCtr = 0;
  int rxCtr = 1;

  XBeeEncrypter(String keyHex, this.txNonce, this.rxNonce) {
    xx = x.Encrypter(
      x.AES(
        x.Key.fromBase16(keyHex),
        mode: x.AESMode.ctr,
        padding: null,
      ),
    );
  }

  List<int> encrypt(List<int> plaintext) {
    // offset the plaintext message
    int initialOffset = txByteCtr;
    List<int> offsetPlaintext = offset(initialOffset, plaintext);

    // encrypt the whole thing
    var encrypted = xx
        .encrypt(
          utf8.decode(offsetPlaintext),
          iv: x.IV.fromBase16(rxNonce + getCounterHex(rxCtr)),
        )
        .bytes;
   
    // adjust the counters
    adjustCounters(Mode.ENCRYPTING, plaintext.length);

    // trim the encrypted offset
    encrypted = encrypted.sublist(initialOffset, encrypted.length);

    return encrypted;
  }

  List<int> encryptFromString(String plaintext) {
    return encrypt(utf8.encode(plaintext));
  }

  List<int> decrypt(List<int> encrypted) {
    // offset the encrypted message
    int initialOffset = rxByteCtr;
    List<int> offsetEncrypted = offset(initialOffset, encrypted);

    // decrypt the whole thing
    var decrypted = xx.decryptBytes(
      x.Encrypted.fromBase16(hex.encode(offsetEncrypted)),
      iv: x.IV.fromBase16(rxNonce + getCounterHex(rxCtr)),
    );
    
    // adjust the counters
    adjustCounters(Mode.DECRYPTING, encrypted.length);

    // trim the decrypted offset
    decrypted = decrypted.sublist(initialOffset, decrypted.length);

    return decrypted;
  }

  String decryptToString(List<int> encrypted) {
    return utf8.decode(decrypt(encrypted));
  }

  String getCounterHex(int ctr) {
    return ctr.toRadixString(16).padLeft(8, '0');
  }

  List<int> offset(int numBytes, List<int> input) {
    if (numBytes == 0) return input;
    final offsetInts = List<int>.generate(numBytes, (_) => 0);
    return [...offsetInts, ...input];
  }

  /// Adjusts the appropriate counters.
  void adjustCounters(Mode mode, int len) {
    switch (mode) {
      case Mode.ENCRYPTING:
        {
          final amt = adjAmounts(txByteCtr, len);
          txByteCtr = amt[0];
          txCtr += amt[1];
        }
        break;
      case Mode.DECRYPTING:
        {
          final amt = adjAmounts(rxByteCtr, len);
          rxByteCtr = amt[0];
          rxCtr += amt[1];
        }
        break;
    }
  }

  /// Gives the amount of adjustment.
  ///
  /// output[0] = new byte counter
  /// output[1] = increment amount to big counter
  List<int> adjAmounts(int initialBytes, int len) {
    int counterIncrease = len ~/ 16;
    int remainder = len % 16;

    int newByte = (initialBytes + remainder) % 16;
    return [
      newByte,
      counterIncrease + ((initialBytes + remainder) ~/ 16),
    ];
  }
}

enum Mode { ENCRYPTING, DECRYPTING }

String getCounterHex(int ctr) {
  return ctr.toRadixString(16).padLeft(8, '0');
}

main() {
  //   final aes = x.AES(
  //   x.Key.fromSecureRandom(32),
  //   mode: x.AESMode.ctr,
  //   padding: null,
  // );
  // final enc = x.Encrypter(aes);
  // final nonceHex = x.Key.fromSecureRandom(12).base16;

  // t1(enc, nonceHex);
  // t2(enc, nonceHex);

  final nonce = hex.encode(x.Key.fromSecureRandom(12).bytes);
  XBeeEncrypter xbe = XBeeEncrypter(
    hex.encode(x.Key.fromSecureRandom(32).bytes),
    hex.encode(x.Key.fromSecureRandom(12).bytes),
    nonce,
  );
  // final msg = '01234567890123456789';
  // final encrypted = xbe.encryptFromString(msg);
  // print('encrypted: $encrypted');
  // final decrypted = xbe.decryptToString(encrypted);
  // print('decrypted: $decrypted');

  final msg0 = '0123456';
  final msg1 = '789012345789';
  final enc0 = xbe.encryptFromString(msg0);
  final enc1 = xbe.encryptFromString(msg1);

  final decrypted0 = xbe.decryptToString([...enc0,...enc1]);
  print(decrypted0);
  
}

void t1(x.Encrypter enc, String nonceHex) {
  print('trial 1');

  final iv0 = x.IV.fromBase16(nonceHex + getCounterHex(1));

  final msg0 = '01234567890123456789'; // 6789 is in the next block
  // final msg1 = '6789';

  final encryptedMsg0 = enc.encrypt(msg0, iv: iv0);
  final encryptedMsg1 =
      x.Encrypted.fromBase16(hex.encode(encryptedMsg0.bytes.sublist(0, 16)));
  final encryptedMsg2 = x.Encrypted.fromBase16(
      hex.encode(encryptedMsg0.bytes.sublist(16, encryptedMsg0.bytes.length)));
  print('encrypted bytes 0: ${encryptedMsg0.bytes}');
  print('encrypted bytes 1: ${encryptedMsg1.bytes}');
  print('encrypted bytes 2: ${encryptedMsg2.bytes}');

  final decryptedMsg0 = enc.decrypt(
    encryptedMsg0,
    iv: iv0,
  );
  final decryptedMsg1 = enc.decrypt(
    encryptedMsg1,
    iv: iv0,
  );
  final decryptedMsg2 = enc.decrypt(
    encryptedMsg2,
    iv: x.IV.fromBase16(nonceHex + getCounterHex(2)),
  );
  print('decrypted bytes 0: ${decryptedMsg0.codeUnits}');
  print('decrypted bytes 1: ${decryptedMsg1.codeUnits}');
  print('decrypted bytes 2: ${decryptedMsg2.codeUnits}');
}

void t2(x.Encrypter enc, String nonceHex) {
  print('trial 2');

  final iv0 = x.IV.fromBase16(nonceHex + getCounterHex(1));

  final msg0 = '0123456789012345'; // 6789 is in the next block
  // final msg1 = '6789';

  final encryptedMsg0 = enc.encrypt(msg0, iv: iv0);
  final encryptedMsg1 =
      x.Encrypted.fromBase16(hex.encode(encryptedMsg0.bytes.sublist(10, 16)));
  print('encrypted bytes 0: ${encryptedMsg0.bytes}');
  print('encrypted bytes 1: ${encryptedMsg1.bytes}');

  final decryptedMsg0 = enc.decrypt(
    encryptedMsg0,
    iv: iv0,
  );
  print('decrypted bytes 0: ${decryptedMsg0.codeUnits}');

  final decryptedMsg1 = enc.decrypt(
    x.Encrypted.fromBase16('00000000000000000000' + encryptedMsg1.base16),
    iv: iv0,
  );
  print('decrypted bytes 1: ${decryptedMsg1.codeUnits}');
}
