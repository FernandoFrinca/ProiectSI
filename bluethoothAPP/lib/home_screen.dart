import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as serial_bt;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dht11tempController = TextEditingController();
  final dht11umController = TextEditingController();
  final wlvlController = TextEditingController();
  final mq135Controller = TextEditingController();
  final ldrController = TextEditingController();
  final bondedDevices = ValueNotifier(<serial_bt.BluetoothDevice>[]);
  serial_bt.BluetoothConnection? connection;
  String sensorData = "";
  String buffer = "";

  List<double> dht11TempValues = [];
  List<double> dht11UmValues = [];
  List<double> wlvlValues = [];
  List<double> mq135Values = [];
  List<double> ldrValues = [];

  double dht11TempAverage = 0.0;
  double dht11UmAverage = 0.0;
  double wlvlAverage = 0.0;
  double mq135Average = 0.0;
  double ldrAverage = 0.0;

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();
    requestPermissions();
    getBondedDevices();
  }

  Future<void> requestPermissions() async {
    await Future.wait([
      Permission.bluetooth.request(),
      Permission.bluetoothScan.request(),
      Permission.bluetoothConnect.request(),
    ]);
  }

  void getBondedDevices() async {
    List<serial_bt.BluetoothDevice> devices = [];

    try {
      devices = await serial_bt.FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      print("Error getting bonded devices: $e");
    }

    bondedDevices.value = devices;
  }

  void connectToDevice(serial_bt.BluetoothDevice device) async {
    print("Selected device MAC address: ${device.address}");
    try {
      bool isBonded = await device.isBonded;
      if (!isBonded) {
        bool? bonded = await serial_bt.FlutterBluetoothSerial.instance.bondDeviceAtAddress(device.address, pin: '1234');
        if (!bonded!) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to bond with ${device.name}")),
          );
          return;
        }
      }

      connection = await serial_bt.BluetoothConnection.toAddress(device.address);
      connection?.input?.listen((Uint8List data) {
        buffer += String.fromCharCodes(data);

        if (buffer.contains('\n')) {
          setState(() {
            sensorData = buffer.trim();
            processSensorData(sensorData);
            addDataToFirebase();
            buffer = "";
          });
        }
      }).onDone(() {
        print('Disconnected by remote request');
        setState(() {
          connection = null;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connected to ${device.name}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to connect: $e")),
      );
    }
  }

  void disconnectFromDevice() async {
    if (connection != null) {
      await connection?.close();
      setState(() {
        connection = null;
        sensorData = "";
        buffer = "";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Disconnected from device")),
      );
    }
  }

  void processSensorData(String data) {
    try {
      List<String> pairs = data.split(' ');

      for (var pair in pairs) {
        var keyValue = pair.split(':');
        if (keyValue.length == 2) {
          String key = keyValue[0].trim();
          double value = double.tryParse(keyValue[1].trim()) ?? 0.0;
          if (key == 'DHT11TEMP') {
            dht11TempValues.add(value);
            dht11TempAverage = dht11TempValues.reduce((a, b) => a + b) / dht11TempValues.length;
            print('DHT11TEMP values: $dht11TempValues, average: $dht11TempAverage');
          } else if (key == 'DHT11UM') {
            dht11UmValues.add(value);
            dht11UmAverage = dht11UmValues.reduce((a, b) => a + b) / dht11UmValues.length;
            print('DHT11UM values: $dht11UmValues, average: $dht11UmAverage');
          } else if (key == 'WLVL') {
            wlvlValues.add(value);
            wlvlAverage = wlvlValues.reduce((a, b) => a + b) / wlvlValues.length;
            print('WLVL values: $wlvlValues, average: $wlvlAverage');
          } else if (key == 'MQ135') {
            mq135Values.add(value);
            mq135Average = mq135Values.reduce((a, b) => a + b) / mq135Values.length;
            print('MQ135 values: $mq135Values, average: $mq135Average');
          } else if (key == 'LDR') {
            ldrValues.add(value);
            ldrAverage = ldrValues.reduce((a, b) => a + b) / ldrValues.length;
            print('LDR values: $ldrValues, average: $ldrAverage');
          }
        }
      }

      Map<String, dynamic> jsonData = json.decode(data);

      dht11tempController.text = jsonData['DHT11TEMP']?.toString() ?? '';
      dht11umController.text = jsonData['DHT11UM']?.toString() ?? '';
      ldrController.text = jsonData['LDR']?.toString() ?? '';
      mq135Controller.text = jsonData['MQ135']?.toString() ?? '';
      wlvlController.text = jsonData['WLVL']?.toString() ?? '';

      print('Extracted data: $jsonData');

    } catch (e) {
      print("Error processing sensor data: $e");
    }
  }

  void addDataToFirebase() {
    CollectionReference collref = FirebaseFirestore.instance.collection('SensorsData');
    collref.add({
      'DHT11TEMP': dht11tempController.text.isNotEmpty ? dht11tempController.text : null,
      'DHT11UM': dht11umController.text.isNotEmpty ? dht11umController.text : null,
      'LDR': ldrController.text.isNotEmpty ? ldrController.text : null,
      'MQ135': mq135Controller.text.isNotEmpty ? mq135Controller.text : null,
      'WLVL': wlvlController.text.isNotEmpty ? wlvlController.text : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<serial_bt.BluetoothState>(
      stream: serial_bt.FlutterBluetoothSerial.instance.onStateChanged(),
      initialData: serial_bt.BluetoothState.UNKNOWN,
      builder: (context, snapshot) {
        final bluetoothState = snapshot.data;
        final bluetoothOn = bluetoothState == serial_bt.BluetoothState.STATE_ON;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Bluetooth Connect"),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      bluetoothOn ? "ON" : "OFF",
                      style: TextStyle(
                        color: bluetoothOn ? Colors.green : Colors.red,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: bluetoothOn ? getBondedDevices : null,
                      child: const Text("Refresh Devices"),
                    ),
                  ],
                ),
                if (!bluetoothOn)
                  const Center(
                    child: Text("Turn Bluetooth on"),
                  ),
                ValueListenableBuilder(
                  valueListenable: bondedDevices,
                  builder: (context, devices, child) {
                    return Expanded(
                      child: ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return ListTile(
                            title: Text(device.name ?? "Unknown Device"),
                            subtitle: Text(device.address),
                            onTap: () {
                              connectToDevice(device);
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                const Text(
                  "Sensor Data:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView(
                    
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
                        title: Text(
                          "TEMPERATURE:",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          dht11tempController.text,
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
                        title: Text(
                          "HUMIDITY:",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          dht11umController.text,
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
                        title: Text(
                          "LIGHT:",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          ldrController.text,
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
                        title: Text(
                          "AIR QUALITY:",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          mq135Controller.text,
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
                        title: Text(
                          "WATER LEVEL:",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          wlvlController.text,
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Sensor Averages:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "TEMPERATURE: $dht11TempAverage",
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  "HUMIDITY: $dht11UmAverage",
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  "LIGHT: $ldrAverage",
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  "AIR QUALITY: $mq135Average",
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  "WATER LEVEL: $wlvlAverage",
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          floatingActionButton: connection != null
              ? FloatingActionButton(
                  onPressed: disconnectFromDevice,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.bluetooth_disabled),
                )
              : null,
        );
      },
    );
  }
}
