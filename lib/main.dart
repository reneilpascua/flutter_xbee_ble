import 'dart:async';
import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'xbee_encrypter.dart';
import 'bt_logic.dart' as bt;
import 'xbee_auth.dart';
import 'helpers.dart' as h;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XBee BLE Relay',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: XBeeRelayConsolePage(title: 'XBee BLE Relay'),
    );
  }
}

class XBeeRelayConsolePage extends StatefulWidget {
  XBeeRelayConsolePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _XBeeRelayConsolePageState createState() => _XBeeRelayConsolePageState();
}

class _XBeeRelayConsolePageState extends State<XBeeRelayConsolePage> {
  List<BluetoothDevice> scannedDevices = [];
  List<DropdownMenuItem<BluetoothDevice>> scannedDevicesDDItems = [];
  BluetoothDevice selectedDevice;
  bool scanInProgress = false;
  BluetoothService selectedService;

  StreamSubscription mtuSub;
  StreamSubscription connectionSub;
  StreamSubscription responseSub;
  List<int> latestResponse;
  List<String> incomingData = [
    '🐝 - please ensure your Bluetooth and location services are turned on.',
  ];
  BluetoothCharacteristic writeTarget;

  TextEditingController writeTC = TextEditingController();

  final pw = 'Fathom';
  XBeeAuth xba;
  XBeeEncrypter xbe;
  bool unlocked = false;

  final _payloadTiptext =
      'Write a hex command. It will be wrapped with 7E:LL:LL:...:CS. Check XBee documentation for more info.';
  final _sampleInput = '2D69026869'; // "hi"

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 20),
              headingText('Devices', 16),
              scannedDevicesRow(),
              SizedBox(height: 20),
              headingText('Console', 16),
              consoleSection(),
              SizedBox(height: 20),
              headingText('Write to XBee', 16),
              SizedBox(height: 5),
              writeSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget headingText(String text, double size) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget scannedDevicesRow() {
    return Flex(
      direction: Axis.horizontal,
      children: [
        scannedDevicesDropdown(),
        SizedBox(width: 10),
        scanBtn(),
        SizedBox(width: 5),
        unlockBtn(),
      ],
    );
  }

  Widget scannedDevicesDropdown() {
    return Expanded(
      child: DropdownButton(
        isExpanded: true,
        items: scannedDevicesAsDDItems(),
        value: selectedDevice,
        hint: Text('select an XBee device'),
        onChanged: selectDevice,
      ),
    );
  }

  List<DropdownMenuItem<BluetoothDevice>> scannedDevicesAsDDItems() {
    return List.generate(
      scannedDevices.length,
      (i) => DropdownMenuItem(
        child: Text(scannedDevices[i].name),
        value: scannedDevices[i],
      ),
    );
  }

  ElevatedButton scanBtn() {
    return ElevatedButton(
      onPressed: (scanInProgress) ? null : scanForDevices,
      child: Icon(Icons.find_replace),
    );
  }

  Widget unlockBtn() {
    return ElevatedButton(
      style: (unlocked) ? ElevatedButton.styleFrom(primary: Colors.red) : null,
      onPressed: (selectedService != null)
          ? () {
              if (unlocked) {
                disconnectAndClear();
              } else {
                logData('authenticating with password');
                xba = XBeeAuth(pw);
                try {
                  xbeeUnlock().then((e) {
                    logData('unlock process finished');
                  });
                } catch (e) {
                  logData('error in unlock process: $e', type: 'error');
                  return;
                }
              }
            }
          : null,
      child: Icon(Icons.lock_open),
    );
  }

  Widget consoleSection() {
    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.all(5),
      constraints: BoxConstraints.expand(height: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey, width: 2),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: incomingData
              .map((item) => Container(
                  child: Text(item), padding: EdgeInsets.only(top: 5)))
              .toList(),
        ),
      ),
    );
  }

  Widget writeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(
              child: TextField(
                controller: writeTC,
                decoration: InputDecoration(
                    hintText: 'ex. $_sampleInput ("hi" to micropython)'),
              ),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              child: Icon(Icons.send),
              onPressed: (unlocked) ? sendEncrypted : null,
            ),
          ],
        ),
        SizedBox(height: 5),
        Text(
          _payloadTiptext,
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        Text(
          'To relay text wrap in double quotes (" ").',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Future<void> xbeeUnlock() async {
    // step 1: send A to server
    try {
      sendStep1();
    } on FormatException catch (f) {
      logData('format exception caught. please try again. $f', type: 'error');
      return;
    } catch (e) {
      logData('general error in step 1: $e', type: 'error');
      return;
    }

    try {
      // step 2: server presents salt and B (need to wait)
      await Future.delayed(Duration(seconds: 1));
      processStep2();

      // step 3:  client sends proof M1 to server
      sendStep3();

      // step 4: server sends M2 and nonces to client.
      // client must verify session
      await Future.delayed(Duration(seconds: 1));
      processStep4();
    } catch (e) {
      logData('error in unlock process: $e', type: 'error');
      return;
    }
  }

  void sendEncrypted() {
    List<int> toEncrypt = [];
    try {
      var field = writeTC.text;
      // if surrounded by double quotes, prepend relay frame structure
      if (field.isNotEmpty &&
          field[0] == '"' &&
          field[field.length - 1] == '"') {
        // encode it in hex
        final msg = field.codeUnits.sublist(1, field.length - 1);
        print(msg);
        field = '2d6902' + hex.encode(msg);
      }
      toEncrypt = hex.decode((field.isEmpty) ? _sampleInput : field);
      toEncrypt = [
        126, // 0x7e
        ...h.lengthInts(toEncrypt),
        ...toEncrypt,
        h.getChecksumInt(toEncrypt),
      ];
      logData('raw outgoing: $toEncrypt');
      sendToWriteTarget(xbe.encrypt(toEncrypt));
    } on FormatException catch (fe) {
      logData('ensure content is hex, even length, no spaces. $fe',
          type: 'error');
      return;
    } catch (e) {
      logData('error in sending encrypted content. $e', type: 'error');
    }
  }

  void sendStep1() {
    logData('step 1: client presents A to server');
    final send = xba.step1();
    sendToWriteTarget(send);
  }

  void processStep2() {
    logData('step 2: server presents salt and B to client');
    if (latestResponse == null) return;

    xba.step2(latestResponse);
  }

  void sendStep3() {
    logData('step 3: client sends proof M1 to server');
    final send = xba.step3();
    sendToWriteTarget(send);
  }

  void processStep4() {
    logData('step 4: server sends M2 and nonces to client');
    if (latestResponse == null) return;

    try {
      xba.step4(latestResponse);
      unlocked = true;
    } catch (e) {
      logData('error in verifying session $e', type: 'error');
      return;
    }

    // create the encrypter
    xbe = XBeeEncrypter(xba.sesh.key, xba.txNonce, xba.rxNonce);
  }

  void sendToWriteTarget(List<int> send) {
    logData(send.toString(), type: 'out');
    writeTarget.write(send);
  }

  void selectDevice(BluetoothDevice btd) {
    setState(() {
      selectedDevice = btd;
    });

    // connect device to flutter_blue instance (async)
    connectAndDiscover();
  }

  Future<void> connectAndDiscover() async {
    logData('attempting connection with ${selectedDevice.name}');
    bt.connectToDevice(selectedDevice).then((success) async {
      if (!success) {
        logData('unsuccessful connection with ${selectedDevice.name}',
            type: 'error');
        disconnectAndClear();
        return;
      } else {
        // discover services then characteristics
        final discoveredServices =
            await bt.discoverCharacteristics(selectedDevice);
        logData('searching for XBee API service...');

        // see if this has the xbee ble api service
        BluetoothService theOne;
        for (BluetoothService bts in discoveredServices) {
          if (bts.uuid.toString() == '53da53b9-0447-425a-b9ea-9837505eb59a') {
            theOne = bts;
            break;
          }
        }

        if (theOne == null) {
          logData('xbee api service not found. disconnecting.', type: 'error');
          disconnectAndClear();
          return;
        }

        // request max MTU
        try {
          logData('requesting mtu of 512...');
          selectedDevice.requestMtu(512).then((_) async {
            await Future.delayed(Duration(seconds: 1));
            mtuSub = selectedDevice.mtu.listen((newmtu) {
              logData('new mtu: ${newmtu.toString()}');
            });
          });
        } catch (e) {
          logData('error during mtu request: $e', type: 'error');
          return;
        }

        // wait a second for the MTU request to finalize
        await Future.delayed(Duration(seconds: 1));

        // assign connection state listener
        connectionSub = selectedDevice.state.listen((state) {
          if (state == BluetoothDeviceState.disconnected) {
            logData('device disconnected', type: 'error');
            scannedDevices.clear();
            disconnectAndClear();
          }
        });

        logData('connected.');

        selectedService = theOne;
        handleSelectedServ();

        // re-render
        setState(() {});
      }
    });
  }

  void scanForDevices() async {
    logData('scanning...');
    // reset scan results and disable button
    resetState();
    setState(() {
      scanInProgress = true;
    });

    try {
      // use flutter_blue to scan, then create dropdown items
      scannedDevices = await bt.scanForDevices();
    } catch (e) {
      logData('check if bluetooth and location are on! error: $e',
          type: 'error');
      setState(() {
        scanInProgress = false;
      });
      return;
    }

    logData('finished scanning.');
    // enable scan button
    setState(() {
      scanInProgress = false;
    });
  }

  void handleSelectedServ() async {
    selectedService.characteristics.forEach((char) {
      if (char.properties.notify || char.properties.indicate) {
        logData('subscribing to updates from ${char.uuid}');
        responseSub?.cancel();
        responseSub = char.value.listen(
          responseCallback,
          cancelOnError: true,
        );
        char.setNotifyValue(true);
      }

      if (char.properties.write) {
        logData('writes will go to ${char.uuid}');
        writeTarget = char;
      }
    });
  }

  void responseCallback(List<int> val) {
    latestResponse = val;
    logData('raw incoming: $val', type: 'in');
    if (unlocked) {
      final decrypted = decrypt(val);
      logData('decrypted: $decrypted');

      if (decrypted.length > 4 && decrypted[3] == 173) {
        //173 = 0xAD = user data
        try {
          logData(
              'user data: ${utf8.decode(decrypted.sublist(5, decrypted.length - 1))}');
        } catch (e) {
          logData('had trouble decoding user data. $e', type: 'error');
        }
      }
    }
  }

  final _LOG_EMOJIS = {'in': '📲', 'out': '📤', 'error': '❌', 'info': 'ℹ️'};
  void logData(String item, {String type}) {
    if (incomingData.length >= 25) {
      incomingData.removeLast();
    }
    final pre = type ?? 'info';
    final msg = '${_LOG_EMOJIS[pre]} - $item';

    print(msg);
    setState(() {
      incomingData.insert(0, '${h.getNowTime()} - $msg');
    });
  }

  List<int> decrypt(List<int> val) {
    // TODO: differentiate return by utf8 or just bytes
    return xbe.decrypt(val);
  }

  void resetState() {
    resetAuth();
    setState(() {
      mtuSub?.cancel();
      responseSub?.cancel();
      connectionSub?.cancel();
      writeTarget = null;
      selectedService = null;
      selectedDevice = null;
      scannedDevices.clear();
      scannedDevicesDDItems.clear();
    });
  }

  void resetAuth() {
    xba = null;
    xbe = null;
    unlocked = false;
  }

  void disconnectAndClear() {
    selectedDevice?.disconnect();

    mtuSub?.cancel();
    responseSub?.cancel();
    connectionSub?.cancel();

    resetAuth();
    selectedService = null;
    setState(() {
      selectedDevice = null;
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    disconnectAndClear();
    super.dispose();
  }
}
