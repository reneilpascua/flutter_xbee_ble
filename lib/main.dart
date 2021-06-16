import 'dart:async';
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
      home: MyHomePage(title: 'XBee BLE Test'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<BluetoothDevice> scannedDevices = [];
  List<DropdownMenuItem<BluetoothDevice>> scannedDevicesDDItems = [];
  BluetoothDevice selectedDevice;
  bool scanInProgress = false;

  List<BluetoothService> discoveredServices = [];
  BluetoothService selectedService;

  StreamSubscription sub;
  List<int> latestResponse;
  List<String> incomingData = ['ℹ️ - notification / indication values go here...'];
  BluetoothCharacteristic writeTarget;

  TextEditingController writeTC = TextEditingController();
  ScrollController sc = ScrollController();

  XBeeAuth xba;
  bool unlocked = false;
  x.Encrypter encrypter;
  int ivCounter = 1;
  String ivCounterHex = '00000001';



  @override
  void initState() {
    super.initState();
    xba = XBeeAuth('Fathom');
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
                readSection(),
                SizedBox(height: 30),
                headingText('Send Payload', 16),
                // headingText('XBee Unlock', 16),
                // sendRequestSection(),
                writeSection(),
              ],
            ),
          )),
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
        SizedBox(width:5),
        ElevatedButton(
          onPressed: () {
            try {
              xbeeUnlock().then((e) {
                logData('unlock process finished');
              });
            } catch (e) {
              logData('error in unlock process: $e',prefix:'error');
            }
          },
          child: Icon(Icons.lock_open),
        )
      ],
    );
  }

  Widget scannedDevicesDropdown() {
    return Expanded(
      child: DropdownButton(
        isExpanded: true,
        items: scannedDevicesAsDropdown(),
        value: selectedDevice,
        hint: Text('scan to find devices'),
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

  Widget readSection() {
    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.all(5),
      constraints: BoxConstraints.expand(height: 300),
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
            decoration: InputDecoration(
              hintText: (writeTarget == null)
                  ? "no write characteristic found"
                  : writeTarget.uuid.toString(),
            ),
          ),
        ),
        SizedBox(width: 10),
        ElevatedButton(
          child: Icon(Icons.send),
          // onPressed: sendToWriteTarget,
        ),
      ],
    );
  }

  Future<void> xbeeUnlock() async {
    // step 1: send A to server
    try {
      sendStep1();
    } on FormatException {
      logData('odd ephemeral generated. please try again',prefix:'error');
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
      logData('error in verifying session $e', prefix: 'error');
      return;
    }

    // create the aes algo and encrypter
    final aes = x.AES(
      x.Key.fromBase16(xba.sesh.key),
      mode: x.AESMode.ctr,
      padding: null,
    );
    encrypter = x.Encrypter(aes);

    final aes2 = x.AES(
      x.Key.fromBase16(xba.sesh.key),
      mode: x.AESMode.sic,
    );
  }

  void sendToWriteTarget(List<int> send) {
    logData(send.toString(), prefix:'out');
    writeTarget.write(send);
  }

  void sendEncrypted() {
    try {
      final decoded = hex.decode(writeTC.text);
      
    } on FormatException {
      logData('written command must be in hex',prefix: 'error');
    }
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
        logData('unsuccessful connection', prefix: 'error');
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
          logData('error during mtu request: $e', prefix: 'error');
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
    sub?.cancel();
    var alreadySubbedToSomething = false;
    selectedService.characteristics.forEach((char) {
      if (char.properties.notify || char.properties.indicate) {
        logData(
            'subscribing to notifications / indications for only ${char.uuid}');
        if (!alreadySubbedToSomething) {
          sub = char.value.listen(
            (val) {
              latestResponse = val;
              logData('raw: $val',prefix:'in');

              if (unlocked) {
                logData(decryptAES(hex.encode(val)),prefix:'in');
              }
            },
            cancelOnError: true,
          );
          char.setNotifyValue(true);
        }
      }

      if (char.properties.write) {
        logData('writes will go to ${char.uuid}');
        writeTarget = char;
      }
    });
  }

  static const LOG_EMOJIS = {
    'in': '📲',
    'out': '🔜',
    'error': '❌',
    'info': 'ℹ️'
  };
  void logData(String item, {String prefix}) {
    if (incomingData.length >= 25) {
      incomingData.removeLast();
    }
    final pre = prefix ?? 'info';
    final msg = '${LOG_EMOJIS[pre]} - $item';
    
    print(msg);
    setState(() {
      incomingData.insert(0, '${getNowTime()} - $msg');
    });
  }

  String getNowTime() {
    return '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
  }

  String decryptAES(String encryptedHexString) {
    print('input: $encryptedHexString');

    final ivhex = '${xba.rxNonce}$ivCounterHex';
    final ivee = x.IV.fromBase16(ivhex);
    print('iv: ${ivee.base16}');

    final decrypted16 = encrypter.decrypt16(encryptedHexString, iv: ivee);
    print('decrypted [length ${decrypted16.length}]: $decrypted16');

    incrCounter(decrypted16.length);
    return decrypted16.substring(5,decrypted16.length-1);
  }

  void incrCounter(int magnitude) {
    final incr = magnitude ~/ 16;
    ivCounter += incr;

    // convert to padded hex
    ivCounterHex = ivCounter.toRadixString(16).padLeft(8,'0');
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
