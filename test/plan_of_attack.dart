import 'package:srp/client.dart';
import 'package:convert/convert.dart';

//////////////////
/// PLAN OF ATTACK
//////////////////

/// notes:
/// - the params object is a bunch of hardcoded parameters that this lib uses
/// - for the XBee, I (aka Identity) is hardcoded to 'apiservice'

///	STEP 0 - client prepares its keys

const I = 'apiservice';
const password = 'Fathom';
final salt = generateSalt();
final priv = derivePrivateKey(salt, I, password);

final eph = generateEphemeral();
// eph.secret is 64 hex digits (32B)
// eph.public is 512 hex digits (256B)


///	STEP 1 - client presents A to server

// convert eph to list of ints
final ephInts = hex.decode(eph.public);

/// Driver
main() {
  // print('ephemeral secret: ${eph.secret}');
  // print('public ephemeral (${eph.public.length} digits)');
  // print(eph.public);
  // print('converted to ${ephInts.length} ints');
  // print(ephInts);

  String hexString = '6380690410d28500eb';
  final decoded = hex.decode(hexString);
  print(decoded);
  final strung = hex.encode(decoded);
  print(strung);
}