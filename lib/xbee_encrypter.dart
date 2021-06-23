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

  List<int> encrypt2() {
    var toEncrypt = '2D00026869';
    // var toEncrypt = '08175450';
    final decoded = hex.decode(toEncrypt);

    final encrypted = encrypt2helper(decoded);
    return encrypted;
  }

  List<int> encrypt2helper(List<int> bytes) {
    // pad data
    // final paddedBytes = padWithNulls(bytes);
    final paddedBytes = bytes;

    // add frames
    List<int> toEncrypt = [
      126, // 0x7e
      ...lengthInts(paddedBytes),
      ...paddedBytes,
      getChecksumInt(paddedBytes),
    ];

    // create initialization vector
    final ivhex = '$txNonce${getCounterHex(txCtr)}';
    final ivee = x.IV.fromBase16(ivhex);
    print('iv: ${ivee.base16}');

    // encrypt
    final encrypted = xbe.encryptBytes(toEncrypt, iv: ivee);
    print('encrypted [length ${encrypted.bytes.length}]: ${encrypted.bytes}');

    // increment the counter by how many blocks
    txCtr += encrypted.bytes.length ~/ 16;
    return encrypted.bytes;
  }

  List<int> padWithNulls(List<int> original) {
    var newlist = List<int>.from(original);
    while ((newlist.length + 4) % 16 != 0) {
      newlist.add(0);
    }
    return newlist;
  }

  List<int> lengthInts(List<int> data) {
    // return 2 bytes representing length of the data
    return hex.decode(hex.encode([data.length]).padLeft(4, '0'));
  }

  int getChecksumInt(List<int> data) {
    final intsum = listSum(data);
    final hexsum = intsum.toRadixString(16);

    // truncate and subtract from 0xFF (255 in decimal)
    final last2Digits = hexsum.substring(hexsum.length - 2, hexsum.length);
    return 255 - int.parse(last2Digits, radix: 16);
  }

  int listSum(List<int> ints) {
    int sum = 0;
    ints.forEach((element) {
      sum += element;
    });
    return sum;
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
          iv: x.IV.fromBase16(txNonce + getCounterHex(txCtr)),
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
