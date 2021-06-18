import 'dart:async';
import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:encrypt/encrypt.dart' as x;

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'bt_logic.dart' as bt;
import 'xbee_auth.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XBee BLE Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: XBeeRelayConsolePage(title: 'XBee BLE Test'),
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

  List<BluetoothService> discoveredServices = [];
  BluetoothService selectedService;

  StreamSubscription sub;
  List<int> latestResponse;
  List<String> incomingData = [
    'ℹ️ - notification / indication values go here...',
  ];
  BluetoothCharacteristic writeTarget;

  TextEditingController writeTC = TextEditingController();
  ScrollController sc = ScrollController();

  XBeeAuth xba = XBeeAuth('Fathom');
  bool unlocked = false;

  x.Encrypter encrypter;
  int incomingCtr = 1;
  int outgoingCtr = 1;

  _SEND_MODE_ENUM mode = _SEND_MODE_ENUM.HEX;

  static const _payloadTiptext =
      'Content will be wrapped with 7E:LL:LL: ... :CS, then encrypted. Check XBee documentation for more info.';
  static const _sampleInput = '2D00026869';

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
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              headingText('Devices', 16),
              scannedDevicesRow(),
              SizedBox(height: 10),
              headingText('Services', 16),
              servicesDropdown(),
              SizedBox(height: 30),
              headingText('Console', 16),
              consoleSection(),
              SizedBox(height: 30),
              headingText('Write to XBee', 16),
              radioRow(),
              writeSection(),
              SizedBox(height: 5),
              Text(_payloadTiptext,
                  style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }

  Widget radioRow() {
    return Row(
      children: <Widget>[
        Text('Input mode:'),
        Flexible(
          child: ListTile(
            title: const Text('Hex'),
            leading: Radio<_SEND_MODE_ENUM>(
              value: _SEND_MODE_ENUM.HEX,
              groupValue: mode,
              onChanged: (value) {
                setState(() {
                  mode = value;
                });
              },
            ),
          ),
        ),
        Flexible(
          child: ListTile(
            title: const Text('Text'),
            leading: Radio<_SEND_MODE_ENUM>(
              value: _SEND_MODE_ENUM.ASCII_TEXT,
              groupValue: mode,
              onChanged: (value) {
                setState(() {
                  mode = value;
                });
              },
            ),
          ),
        ),
      ],
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
        items: scannedDevicesAsDropdown(),
        value: selectedDevice,
        hint: Text('select an XBee device'),
        onChanged: selectDevice,
      ),
    );
  }

  ElevatedButton scanBtn() {
    return ElevatedButton(
      onPressed: (scanInProgress) ? null : scanForDevices,
      child: Icon(Icons.find_replace),
    );
  }

  Widget servicesDropdown() {
    return DropdownButton(
      isExpanded: true,
      value: selectedService,
      items: discCharsAsDropdown(),
      hint: Text('discovered services'),
      onChanged: selectServ,
    );
  }

  List<DropdownMenuItem<BluetoothDevice>> scannedDevicesAsDropdown() {
    return List.generate(
      scannedDevices.length,
      (i) => DropdownMenuItem(
        child: Text(scannedDevices[i].name),
        value: scannedDevices[i],
      ),
    );
  }

  List<DropdownMenuItem<BluetoothService>> discCharsAsDropdown() {
    return List.generate(
      discoveredServices.length,
      (i) => DropdownMenuItem(
        child: Text('service ${discoveredServices[i].uuid}'),
        value: discoveredServices[i],
      ),
    );
  }

  Widget consoleSection() {
    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.all(5),
      constraints: BoxConstraints.expand(height: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey, width: 2),
      ),
      child: SingleChildScrollView(
        controller: sc,
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
    return Flex(
      direction: Axis.horizontal,
      children: [
        Expanded(
          child: TextField(
            controller: writeTC,
            decoration: InputDecoration(hintText: 'ex: $_sampleInput ("hi")'),
          ),
        ),
        SizedBox(width: 10),
        ElevatedButton(
          child: Icon(Icons.send),
          onPressed: (unlocked) ? sendEncrypted : null,
        ),
      ],
    );
  }

  Widget unlockBtn() {
    return ElevatedButton(
      style: (unlocked) ? ElevatedButton.styleFrom(primary: Colors.red) : null,
      onPressed: (selectedDevice != null)
          ? () {
              if (unlocked) {
                // disconnect
                logData('disconnect not implemented yet', type: 'error');
              } else {
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

  void sendEncrypted() {
    final defaultIn = (mode == _SEND_MODE_ENUM.HEX) ? _sampleInput : 'hi';
    var toEncrypt = (writeTC.text.isNotEmpty) ? writeTC.text : defaultIn;

    if (mode == _SEND_MODE_ENUM.ASCII_TEXT) {
      toEncrypt = '2D0002' +
          hex.encode(utf8.encode(
              toEncrypt)); // data input 0x2d, frame id 0x00, interface 0x02
    }

    try {
      final decoded = hex.decode(toEncrypt);
      logData('raw: $decoded', type: 'out');

      final encrypted = encryptAES(decoded);
      sendToWriteTarget(encrypted);
    } on FormatException {
      if (mode == _SEND_MODE_ENUM.HEX)
        logData('content must be in hex, even length, no spaces',
            type: 'error');
      return;
    } catch (e) {
      logData('error when sending: $e', type: 'error');
      return;
    }
  }

  Future<void> xbeeUnlock() async {
    // step 1: send A to server
    try {
      sendStep1();
    } on FormatException {
      logData('odd ephemeral generated. please try again', type: 'error');
      return;
    } catch (e) {
      logData('error in step 1: $e', type: 'error');
      return;
    }

    // step 2: server presents salt and B (need to wait)
    await Future.delayed(Duration(seconds: 1));
    processStep2();

    // step 3:  client sends proof M1 to server
    sendStep3();

    // step 4: server sends M2 and nonces to client.
    // client must verify session
    await Future.delayed(Duration(seconds: 1));
    processStep4();
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

    // create the aes algo and encrypter
    createAES();
  }

  void createAES() {
    final aes = x.AES(
      x.Key.fromBase16(xba.sesh.key),
      mode: x.AESMode.ctr,
      padding: null,
    );
    encrypter = x.Encrypter(aes);
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

  void connectAndDiscover() async {
    bt.connectToDevice(selectedDevice).then((success) async {
      if (!success) {
        logData('unsuccessful connection', type: 'error');
        return;
      } else {
        // discover services then characteristics
        discoveredServices = await bt.discoverCharacteristics(selectedDevice);

        // request max MTU
        try {
          logData('requesting mtu of 512...');
          selectedDevice.requestMtu(512).then((_) async {
            await Future.delayed(Duration(seconds: 1));
            sub = selectedDevice.mtu.listen((newmtu) {
              logData('new mtu: ${newmtu.toString()}');
            });
          });
        } catch (e) {
          logData('error during mtu request: $e', type: 'error');
          return;
        }

        // re-render
        setState(() {});
      }
    });
  }

  void selectServ(BluetoothService bts) {
    setState(() {
      selectedService = bts;
    });

    handleSelectedServ();
  }

  void scanForDevices() async {
    // reset scan results and disable button
    resetState();
    setState(() {
      scanInProgress = true;
    });

    // use flutter_blue to scan, then create dropdown items
    scannedDevices = await bt.scanForDevices();

    // enable scan button
    setState(() {
      scanInProgress = false;
    });
  }

  void handleSelectedServ() async {
    selectedService.characteristics.forEach((char) {
      if (char.properties.notify || char.properties.indicate) {
        logData('subscribing to updates from ${char.uuid}');
        sub?.cancel();
        sub = char.value.listen(
          (val) {
            latestResponse = val;
            logData('raw: $val', type: 'in');
          },
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

  static const _LOG_EMOJIS = {
    'in': '📲',
    'out': '📤',
    'error': '❌',
    'info': 'ℹ️'
  };
  void logData(String item, {String type}) {
    if (incomingData.length >= 25) {
      incomingData.removeLast();
    }
    final pre = type ?? 'info';
    final msg = '${_LOG_EMOJIS[pre]} - $item';

    print(msg);
    setState(() {
      incomingData.insert(0, '${getNowTime()} - $msg');
    });
  }

  String getNowTime() {
    return '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
  }

  String decryptAES(List<int> val) {
    print('to decrypt: $val');

    final ivhex = '${xba.rxNonce}${getCounterHexString(incomingCtr)}';
    final ivee = x.IV.fromBase16(ivhex);
    print('iv: ${ivee.base16}');

    final decrypted = encrypter.decryptBytes(x.Encrypted(val), iv: ivee);
    logData('decrypted (${decrypted.length} bytes): $decrypted');

    final decryptedUtf8 = String.fromCharCodes(decrypted);
    logData('decrypted (utf-8): $decryptedUtf8');

    // increment the counter by how many blocks
    incomingCtr += decrypted.length ~/ 16;
    return decryptedUtf8;
  }

  List<int> encryptAES(List<int> bytes) {
    // pad data
    final paddedBytes = padWithNulls(bytes);

    // add frames
    List<int> toEncrypt = [
      126, // 0x7e
      ...lengthInts(paddedBytes),
      ...paddedBytes,
      getChecksumInt(paddedBytes),
    ];

    // create initialization vector
    final ivhex = '${xba.txNonce}${getCounterHexString(outgoingCtr)}';
    final ivee = x.IV.fromBase16(ivhex);
    print('iv: ${ivee.base16}');

    // encrypt
    final encrypted = encrypter.encryptBytes(toEncrypt, iv: ivee);
    print('encrypted [length ${encrypted.bytes.length}]: ${encrypted.bytes}');

    // increment the counter by how many blocks
    outgoingCtr += encrypted.bytes.length ~/ 16;
    return encrypted.bytes;
  }

  List<int> lengthInts(List<int> data) {
    // return 2 bytes representing length of the data
    return hex.decode(hex.encode([data.length]).padLeft(4, '0'));
  }

  int getChecksumInt(List<int> data) {
    final intsum = xba.listSum(data);
    final hexsum = intsum.toRadixString(16);

    // truncate and subtract from 0xFF (255 in decimal)
    final last2Digits = hexsum.substring(hexsum.length - 2, hexsum.length);
    return 255 - int.parse(last2Digits, radix: 16);
  }

  List<int> padWithNulls(List<int> original) {
    var newlist = List<int>.from(original);
    while ((newlist.length + 4) % 16 != 0) {
      newlist.add(0);
    }
    return newlist;
  }

  String getCounterHexString(int ctr) {
    return ctr.toRadixString(16).padLeft(8, '0');
  }

  void resetState() {
    logData('...');
    setState(() {
      sub?.cancel();
      writeTarget = null;
      selectedService = null;
      discoveredServices.clear();
      selectedDevice = null;
      scannedDevices.clear();
      scannedDevicesDDItems.clear();
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

enum _SEND_MODE_ENUM { ASCII_TEXT, HEX }
