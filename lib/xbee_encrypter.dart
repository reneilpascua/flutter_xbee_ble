import 'package:encrypt/encrypt.dart' as x;
import 'dart:convert' show utf8;
import 'package:convert/convert.dart' show hex;

/// Performs the cryptography required to communicate with XBee.
///
/// Algorithm is AES-256-CTR.
class XBeeEncrypter {
  x.Encrypter xbe;

  String txNonce; // hex string
  int txByteCtr = 0;
  int txCtr = 1;

  String rxNonce; // hex string
  int rxByteCtr = 0;
  int rxCtr = 1;

  XBeeEncrypter(String keyHex, this.txNonce, this.rxNonce) {
    xbe = x.Encrypter(
      x.AES(
        x.Key.fromBase16(keyHex),
        mode: x.AESMode.ctr,
        padding: null,
      ),
    );
  }

  /// Encrypts a byte stream.
  List<int> encrypt(List<int> plaintext) {
    // offset the plaintext message
    int initialOffset = txByteCtr;
    List<int> offsetPlaintext = offset(initialOffset, plaintext);

    // encrypt the whole thing
    var encrypted = xbe
        .encryptBytes(
          offsetPlaintext,
          iv: x.IV.fromBase16(rxNonce + getCounterHex(rxCtr)),
        )
        .bytes;
   
    // adjust the counters
    adjustCounters(Mode.ENCRYPTING, plaintext.length);

    // trim the encrypted offset
    encrypted = encrypted.sublist(initialOffset, encrypted.length);

    return encrypted;
  }

  /// Encrypts a string.
  List<int> encryptFromString(String plaintext) {
    return encrypt(utf8.encode(plaintext));
  }

  /// Decrypts byte input.
  List<int> decrypt(List<int> encrypted) {
    // offset the encrypted message
    int initialOffset = rxByteCtr;
    List<int> offsetEncrypted = offset(initialOffset, encrypted);

    // decrypt the whole thing
    var decrypted = xbe.decryptBytes(
      x.Encrypted.fromBase16(hex.encode(offsetEncrypted)),
      iv: x.IV.fromBase16(rxNonce + getCounterHex(rxCtr)),
    );
    
    // adjust the counters
    adjustCounters(Mode.DECRYPTING, encrypted.length);

    // trim the decrypted offset
    decrypted = decrypted.sublist(initialOffset, decrypted.length);

    return decrypted;
  }

  /// Decrypts input into a string.
  String decryptToString(List<int> encrypted) {
    return utf8.decode(decrypt(encrypted));
  }

  /// Creates a hex string of 4 bytes given a counter.
  String getCounterHex(int ctr) {
    return ctr.toRadixString(16).padLeft(8, '0');
  }

  /// Adds an offset to the input.
  /// 
  /// This is so that the input matches up with the IV.
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
