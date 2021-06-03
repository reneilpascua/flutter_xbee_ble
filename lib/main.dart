import 'dart:async';
import 'package:convert/convert.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'bt_logic.dart' as bt;
import 'xbee_auth.dart';

void main() {
  runApp(MyApp());
}

final exampleHexString =
    '7e00822c010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d1';

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
  List<String> incomingData = ['notification / indication values go here...'];
  BluetoothCharacteristic writeTarget;

  TextEditingController writeTC = TextEditingController();
  ScrollController sc = ScrollController();

  XBeeAuth xba;

  @override
  void initState() {
    super.initState();
    xba = XBeeAuth(password: 'Fathom');
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
                headingText('Incoming Data', 16),
                readSection(),
                SizedBox(height: 30),
                headingText('Send Data', 16),
                // writeSection(),
                sendRequestSection(),
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

  Widget sendRequestSection() {
    return Flex(
      direction: Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          child: Text('S1'),
          onPressed: sendStep1,
        ),
        ElevatedButton(
          child: Text('S2'),
          onPressed: processStep2,
        ),
        ElevatedButton(
          child: Text('S3'),
          onPressed: sendStep3,
        ),
        ElevatedButton(
          child: Text('S4'),
          onPressed: processStep4,
        ),
      ],
    );
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
    print('client salt is: ${xba.salt}');
    print('set server B: ${xba.B}');
  }

  void sendStep3() {
    logData('step 3: client sends proof M1 to server');
    final send = xba.step3();
    sendToWriteTarget(send);
  }

  void processStep4() {
    logData('step 4: server sends M2 and nonces to client');
    if (latestResponse == null) return;

    xba.step4(latestResponse);
  }

  void sendToWriteTarget(List<int> send) {
    logData('writing ${hex.encode(send)}');
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
        // TODO: toast
        print('unsuccessful connection');
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
              print('current mtu: $newmtu');
              logData('new mtu: ${newmtu.toString()}');
            });
          });
        } catch (e) {
          print('error during mtu request$e');
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
    // selectedChar?.setNotifyValue(false);

    // if (selectedService.properties.read) {
    //   final readData = await selectedService.read();
    //   logData('read value: ${Utf8Decoder().convert(readData)}');
    // } else if (selectedService.properties.write) {

    // } else if (selectedService.properties.notify) {
    //   logData('subscribing to notify...');
    //   sub = selectedService.value.listen((val) {
    //     logData('notify value: ${Utf8Decoder().convert(val)}');
    //   }, cancelOnError: true,);
    //   selectedService.setNotifyValue(true);
    // } else if (selectedService.properties.indicate) {
    // }

    // loop through characteristics of this service, assign interactivity
    var alreadySubbedToSomething = false;
    selectedService.characteristics.forEach((char) {
      if (char.properties.notify || char.properties.indicate) {
        logData(
            'subscribing to notifications / indications for only ${char.uuid}');
        if (!alreadySubbedToSomething) {
          sub = char.value.listen(
            (val) {
              print(val);
              latestResponse = val;
              logData('‼️ new value in hex ${hex.encode(val)}');
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
// 87c19f525c2f9a94e20994bc51c8da1ec1ae3a14fa5030cdb46845568286d933
  void logData(String item) {
    setState(() {
      incomingData.add('${getNowTime()} - $item');
      // scroll to the bottom
      sc.animateTo(sc.position.maxScrollExtent,
          duration: Duration(milliseconds: 200), curve: Curves.easeInOut);
      // BUG: this animation happens before rebuild
      // ie. scrolls 1 item from the bottom, not all the way to the bottom.
    });
  }

  String getNowTime() {
    return '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
  }

  void resetState() {
    logData('re-scanning...');
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
