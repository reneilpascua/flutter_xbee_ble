import 'package:srp/client.dart';
import 'package:srp/types.dart';
import 'package:convert/convert.dart';
import 'package:encrypt/encrypt.dart';

/// An encapsulation of the unlock process for XBee.
///
/// Uses secure remote password (SRP): https://asecuritysite.com/encryption/srp
/// This class's members are from the POV of the client.
class XBeeAuth {
  String password; // plaintext
  String salt; // hex string
  String privateKey; // hex string
  String A; // hex string
  String B; // hex string
  Ephemeral eph;
  Session sesh;
  String serverM2; // hex string
  String txNonce; // hex string
  String rxNonce; // hex string

  XBeeAuth(String password) {
    this.password = password;
  }

  /// Generate 'A' value, an ephemeral public key
  ///
  /// Send the returned value to the XBee Server.
  List<int> step1() {
    eph = generateEphemeral();
    // generated public key is 512 hex digits, only need 256 digits, ie. 128B
    // A = eph.public.substring(0, 256);
    A = eph.public;
    String step1String =
        START_DELIMITER + STEP1_LENGTH + BLE_UNLOCK_REQ + '01' + A;
    step1String += calculateXBeeChecksum(BLE_UNLOCK_REQ+'01'+A);

    // return step 1 as a list of ints
    return hex.decode(step1String);
  }

  /// Processes the server response to step 1.
  ///
  /// After invoking this method, the client will be prepared for step 3.
  void step2(List<int> response) {
    verifyResponse(response, 2);

    // all good
    final serverSaltInts = response.sublist(5, 9);
    salt = hex.encode(serverSaltInts);
    final serverPubInts = response.sublist(9, response.length - 1);
    B = hex.encode(serverPubInts);
  }

  /// Generates a request containing a challenge M1.
  ///
  /// Send the returned value to the XBee Server.
  List<int> step3() {

    privateKey = derivePrivateKey(salt, I, password);
    
    sesh = deriveSession(
      eph.secret,
      B,
      salt,
      I,
      privateKey,
    );
    final m1 = sesh.proof;
    print('client session key of length ${m1.length}:');
    print(m1);
    String step3String = START_DELIMITER+STEP3_LENGTH+BLE_UNLOCK_REQ+'03'+m1;
    step3String += calculateXBeeChecksum(BLE_UNLOCK_REQ+'03'+m1);

    // return step 3 string as a list of ints
    return hex.decode(step3String);
  }

  /// Processes the server response to step 3.
  /// 
  /// Will verify the server's proof; if successful, the nonces are
  /// recorded and communication is unlocked.
  void step4(List<int> response) {
    verifyResponse(response, 4);

    serverM2 = hex.encode(response.sublist(5,37));
    verifySession(eph.public, sesh, serverM2);

    txNonce = hex.encode(response.sublist(37,49));
    rxNonce = hex.encode(response.sublist(49,response.length-1));
    print('session key is ${sesh.key}');
  }

  /// Calculates the checksum.
  ///
  /// For the XBee, this is 0xFF minus the 8-bit sum
  String calculateXBeeChecksum(String input) {
    // calc sum
    final intSum = listSum(hex.decode(input));
    final hexSum = intSum.toRadixString(16);

    // truncate and subtract from 0xFF (255 in decimal)
    final last2Digits = hexSum.substring(hexSum.length - 2, hexSum.length);
    final checksumInt = 255 - int.parse(last2Digits, radix: 16);
    return checksumInt.toRadixString(16);
  }

  /// Verifies the response of the XBee.
  /// 
  /// If there are any problems, an exception will be thrown.
  void verifyResponse(List<int> response, int expectedStep) {
    // check if the step frame is correct
    if (response[4] != expectedStep) {
      throw Exception(ERRORS_IN_STEP_FRAME[response[4]] ??
          'Error in step $expectedStep: 0x${response[4].toRadixString(16)}');
    }

    // checksum
    final responseChecksum = response[response.length - 1].toRadixString(16);
    final calculatedChecksum = calculateXBeeChecksum(
        hex.encode(response.sublist(3, response.length - 1)));
    if (responseChecksum != calculatedChecksum) {
      throw Exception(
          'The received checksum $responseChecksum did not match the calculated checksum $calculatedChecksum');
    } // throws exception
  }

  int listSum(List<int> ints) {
    int sum = 0;
    ints.forEach((element) {
      sum += element;
    });
    return sum;
  }
}

//
// CONSTANTS
//

const I = 'apiservice';
const START_DELIMITER = '7e';
const BLE_UNLOCK_REQ = '2c';
const BLE_UNLOCK_RES = 'ac';

/// maps the step frame to an error message
const ERRORS_IN_STEP_FRAME = {
  128:
      '0x80: Unable to offer B; cryptographic error, usually due to (A mod N == 0)',
  129: '0x81: Incorrect payload length',
  130: '0x82: Bad proof of key',
  131: '0x83: Resource allocation error',
  132: '0x84: Request contained a step not in the correct sequence'
};

const STEP1_LENGTH = '0082'; // 130 in base 10 (unit: Bytes)
const STEP3_LENGTH = '0022'; // 34 in base 10 (unit: Bytes)

void main0() {
  final plainText = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit';
  final key = Key.fromUtf8('my 32 length key................');
  final iv = IV.fromLength(16);

  final encrypter = Encrypter(AES(key));

  final encrypted = encrypter.encrypt(plainText, iv: iv);
  final decrypted = encrypter.decrypt(encrypted, iv: iv);
  final decrypted2 = encrypter.decrypt(encrypted, iv: iv);


  print(decrypted); // Lorem ipsum dolor sit amet, consectetur adipiscing elit
  print(decrypted2);
  print(encrypted.base64); // R4PxiU3h8YoIRqVowBXm36ZcCeNeZ4s1OvVBTfFlZRdmohQqOpPQqD1YecJeZMAop/hZ4OxqgC1WtwvX/hP9mw==
}

void main1() {
  final plainText = 'helloworld';
  final key = Key.fromUtf8('my 32 length key................');
  var iv = IV.fromBase16('0001');

  final encrypter = Encrypter(AES(key));

  final encrypted = encrypter.encrypt(plainText, iv: iv);
  print(encrypted.base16);

  final decrypted = encrypter.decrypt(encrypted, iv: iv);
  print(decrypted);

  final decrypted2 = encrypter.decrypt(encrypted, iv: IV.fromBase16('000b'));
  print(decrypted2);
}