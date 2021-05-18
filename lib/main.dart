import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'bt_logic.dart' as bt;

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

  List<BluetoothCharacteristic> discoveredChars = [];
  BluetoothCharacteristic selectedChar;

  StreamSubscription sub;
  List<String> incomingData = ['data displayed here...'];

  TextEditingController writeTC = TextEditingController();
  ScrollController sc = ScrollController();

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
                headingText('Characteristics', 16),
                charsDropdown(),
                SizedBox(height: 30),
                headingText('Incoming Data', 16),
                readSection(),
                SizedBox(height: 30),
                headingText('Send Data', 16),
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
      ],
    );
  }

  Widget scannedDevicesDropdown() {
    return Expanded(
      child: DropdownButton(
        isExpanded: true,
        items: scannedDevicesAsDropdown(),
        value: selectedDevice,
        hint: Text('press scan button to find devices'),
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

  Widget charsDropdown() {
    return DropdownButton(
      isExpanded: true,
      value: selectedChar,
      items: discCharsAsDropdown(),
      hint: Text('discovered characteristics'),
      onChanged: selectChar,
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

  List<DropdownMenuItem<BluetoothCharacteristic>> discCharsAsDropdown() {
    return List.generate(
      discoveredChars.length,
      (i) => DropdownMenuItem(
        child: Text(
            'service ${discoveredChars[i].serviceUuid.toString().substring(0, 8)} :: ${bt.getFirstProperty(discoveredChars[i])}'),
        value: discoveredChars[i],
      ),
    );
  }

  Widget readSection() {
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
          children: incomingData.map((item) => Container(child:Text(item), padding: EdgeInsets.only(top: 5))).toList(),
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
        )),
        SizedBox(width: 10),
        ElevatedButton(child: Icon(Icons.send)),
      ],
    );
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
        // TODO: toast
        print('unsuccessful connection');
        return;
      } else {
        // discover services then characteristics
        discoveredChars = await bt.discoverCharacteristics(selectedDevice);

        // re-render
        setState(() {});
      }
    });
  }

  void selectChar(BluetoothCharacteristic btc) {

    setState(() {
      selectedChar = btc;
    });

    handleSelectedChar();
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

  void handleSelectedChar() async {

    sub?.cancel();
    // selectedChar?.setNotifyValue(false);

    if (selectedChar.properties.read) {
      final readData = await selectedChar.read();
      logData('read value: ${Utf8Decoder().convert(readData)}');
    } else if (selectedChar.properties.write) {

    } else if (selectedChar.properties.notify) {
      logData('subscribing to notify...');
      sub = selectedChar.value.listen((val) {
        logData('notify value: ${Utf8Decoder().convert(val)}');
      });
      selectedChar.setNotifyValue(true);
    } else if (selectedChar.properties.indicate) {

    }
  }

  void logData(String item) {
    setState(() {
      incomingData.add('${getNowTime()} - $item');
      // scroll to the bottom
      sc.animateTo(sc.position.maxScrollExtent, duration: Duration(milliseconds: 200), curve: Curves.easeInOut);
      // BUG: this animation happens before rebuild
      // ie. scrolls 1 item from the bottom, not all the way to the bottom.
    });
  }

  String getNowTime() {
    return '${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}:${DateTime.now().second.toString().padLeft(2,'0')}';
  }

  void resetState() {
    logData('re-scanning...');
    setState(() {
      sub?.cancel();
      selectedChar = null;
      discoveredChars.clear();
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
