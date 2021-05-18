import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_blue/gen/flutterblue.pbjson.dart';

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

Future<bool> connectToDevice(BluetoothDevice btd) async {
  // get list of connected devices, to check whether already connected
  final connectedDevices = await fb.connectedDevices;

  if (connectedDevices.contains(btd)) {
    print('already connected to ${btd.name}');
  } else {
    try {
      await btd.connect();
      print('connected to ${btd.name}');
    } catch (e) {
      print('error connecting to device $e');
      return false;
    }
  }

  return true; // success
}

Future<List<BluetoothCharacteristic>> discoverCharacteristics(
    BluetoothDevice btd) async {
  List<BluetoothCharacteristic> btcs = [];
  final services = await btd.discoverServices();

  for (final service in services) {
    btcs.addAll(service.characteristics);
  }

  return btcs;
}

String getFirstProperty(BluetoothCharacteristic c) {
  var p = c.properties;
  if (p.read) return 'read';
  else if (p.write) return 'write';
  else if (p.notify) return 'notify';
  else if (p.indicate) return 'indicate';
  else return 'n/a';
}

// enum Property {
//   READ,
//   WRITE,
//   NOTIFY,
//   INDICATE
// }

// Map<Property, String> propertyMap = {
//   Property.READ: 'read',
//   Property.WRITE: 'write',
//   Property.NOTIFY: 'notify',
//   Property.INDICATE: 'indicate',
// };
