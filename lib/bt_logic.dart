import 'package:flutter_blue/flutter_blue.dart';

final FlutterBlue fb = FlutterBlue.instance;

Future<List<BluetoothDevice>> scanForDevices() async {
  // list to store devices found in the scan
  List<BluetoothDevice> scannedDevices = [];

  // register method which will listen to scan and add to devices list
  fb.scanResults.listen((List<ScanResult> results) {
    for (final result in results) {
      final device = result.device;
      if (!scannedDevices.contains(device) && device.name.isNotEmpty)
        scannedDevices.add(device);
    }
  });

  // run through the whole scan
  await fb.startScan(timeout: Duration(seconds: 2));

  // add connected devices to the list (flutter_blue doesnt by default)
  scannedDevices.addAll(await fb.connectedDevices);

  // return the list
  // print(scannedDevices);
  return scannedDevices;
}

Future<void> disconnectFromAllDevices() async {
  final connectedDevices = await fb.connectedDevices;
  for (final d in connectedDevices) {
    d.disconnect();
  }
}

Future<bool> connectToDevice(BluetoothDevice btd) async {
  // get list of connected devices, to check whether already connected
  final connectedDevices = await fb.connectedDevices;

  if (connectedDevices.contains(btd)) {
    print('already connected to ${btd.name}');
    return true;
  } else {
    print('attempting connection with ${btd.name}');
    try {
      await btd.connect().timeout(Duration(seconds: 3), onTimeout: () {
        throw Exception('timeout');
      });
      print('connected to ${btd.name}');
    } catch (e) {
      print('error connecting to device $e');
      return false;
    }
  }

  return true; // success
}

Future<List<BluetoothService>> discoverCharacteristics(
    BluetoothDevice btd) async {
  final connectedDevices = await fb.connectedDevices;
  if (connectedDevices.contains(btd)) {
  return await btd.discoverServices();

  } else {
    throw Exception('attempted to discover services on a non-connected device.');
  }
}

String getFirstProperty(BluetoothCharacteristic c) {
  var p = c.properties;
  if (p.read) return 'read';
  else if (p.write) return 'write';
  else if (p.notify) return 'notify';
  else if (p.indicate) return 'indicate';
  else return 'n/a';
}

// /// converts an input string to a list of ints.
// /// 
// /// input is a hexadecimal string, ex. '7e00022a01d1'
// /// output is a list of ints (base 10), ranging from 00-ff,
// ///   ie. the input is parsed 2 characters at a time
// List<int> stringToIntList(String input) {
//   // check that the input string is of even length (we want pairs)
//   if (input.length % 2 != 0) {
//     print('incorrect usage: given string is not of even length');
//     return null;
//   }

//   List<int> output = [];
//   for (int i=0; i <= input.length - 2; i+=2) {
//     final s = input.substring(i,i+2);
//     output.add(int.parse(s, radix: 16));
//   }

//   return output;
// }

// String intListToHexString(List<int> input) {
//   var output = '';
//   input.forEach((hex) {output += hex.toRadixString(16).padLeft(2,'0');});
//   return output;
// }

void test() {}
