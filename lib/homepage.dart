import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:newbluetooth/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  BluetoothConnection? connection;
  bool isConnected = false;
  String status = "Waiting for connection...";
  List<BluetoothDevice> bondedDevices = [];
  dynamic selectedNumber;
  Timer? logoutTimer;
  Timer? timer;
  dynamic selectedValue;
  int secondsRemaining = 10800;
  String timerText = '03:00:00';

  Future<void> _checkSessionValidity() async {
    final prefs = await SharedPreferences.getInstance();
    final loginTime = prefs.getInt('login_time');

    if (loginTime == null) {
      _logout();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final diffInSeconds = (now - loginTime) ~/ 1000;

    if (diffInSeconds >= 10800) {
      _logout();
    } else {
      secondsRemaining = 10800 - diffInSeconds;
      _startTimer();
      logoutTimer ??= Timer(Duration(seconds: secondsRemaining), _logout);
    }
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining > 0) {
        setState(() {
          secondsRemaining--;
          int hours = secondsRemaining ~/ 3600;
          int minutes = (secondsRemaining % 3600) ~/ 60;
          int seconds = secondsRemaining % 60;
          timerText =
              '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        });
      } else {
        timer.cancel();
        _logout();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _checkSessionValidity();
  }

  Future<void> _initBluetooth() async {
    await FlutterBluetoothSerial.instance.requestEnable();
    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() => bondedDevices = devices);

    if (devices.isNotEmpty) {
      _connectToDevice(devices.first);
    } else {
      setState(() => status = "No paired devices found.");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => status = "Connecting to ${device.name}...");
    try {
      final conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        connection = conn;
        isConnected = true;
        status = "Connected to ${device.name}";
      });
      print('Connected to ${device.name}');
    } catch (e) {
      print("Connection failed: $e");
      setState(() => status = "Connection failed");
    }
  }

  void _sendData(int number) {
    if (connection != null && isConnected) {
      String formatted = number.toString().padLeft(3, '0') + ".000";
      connection!.output.add(Uint8List.fromList(formatted.codeUnits));
      print("Sent: $formatted");
      setState(() {
        selectedNumber = number;
      });
    } else {
      print("Not connected.");
    }
  }

  void _sendCustomDecimal(double value) {
    if (connection != null && isConnected) {
      String formatted = value.toStringAsFixed(3).padLeft(7, '0');
      connection!.output.add(Uint8List.fromList(formatted.codeUnits));
      print("Sent: $formatted");

      setState(() {
        selectedNumber = value;
      });
    } else {
      print("Not connected.");
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_time');

    final url = Uri.parse('https://app.1bluetooth.com/api.php?action=logout');

    try {
      final phone = await prefs.getString('phone');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        Fluttertoast.showToast(msg: responseData['message']);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Login()),
          (Route<dynamic> route) => false,
        );
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Device"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: bondedDevices.map((device) {
                return ListTile(
                  title: Text(device.name ?? "Unknown"),
                  subtitle: Text(device.address),
                  onTap: () {
                    Navigator.pop(context);
                    _connectToDevice(device);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allNumbers = [
      0, 0.5, 1, 1.5, 2, 2.5,
      3, 3.5, 4, 4.5, 5, 6,
      7, 8, 9, 10, 11, 12,
      13, 14, 15, 16, 17, 18,
      19, 20, 25, 30, 35, 40,
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 75) / 5;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 50, 50, 50),
      appBar: AppBar(
        title: Text(
          status,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: RawMaterialButton(
              onPressed: _logout,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
                side: const BorderSide(color: Colors.black),
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: isConnected
          ? Column(
            mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (selectedNumber != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    selectedNumber.toString(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 60,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: RawMaterialButton(
                    onPressed: () {
                      _showDeviceSelectionDialog();
                    },
                    fillColor: Colors.green,
                    constraints: BoxConstraints.tightFor(
                      height: 50,
                      width: double.infinity
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      'Connect to Device',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        color: Colors.white
                      ),
                    ),
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    children: [
                      for (int row = 0; row <= (allNumbers.length / 5).floor(); row++)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              int index = row * 5 + i;
                              if (index >= allNumbers.length) {
                                return SizedBox(width: buttonWidth);
                              }

                              final val = allNumbers[index];
                              final isSelected = selectedNumber == val;

                              return number(
                                val.toString(),
                                () {
                                  if (val is int) {
                                    _sendData(val);
                                  } else if (val is double) {
                                    _sendCustomDecimal(val);
                                  }
                                },
                                buttonWidth,
                                isSelected,
                              );
                            }),
                          ),
                        ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
                // const Divider(),
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 15),
                //   child: RawMaterialButton(
                //     onPressed: () {
                //       setState(() {
                //         selectedNumber = null;
                //         status = "Selection cleared.";
                //       });
                //     },
                //     fillColor: Colors.green,
                //     constraints: const BoxConstraints.tightFor(
                //         height: 50, width: double.infinity),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(15),
                //     ),
                //     child: const Text(
                //       'Clear',
                //       style: TextStyle(fontFamily: 'Poppins', fontSize: 22),
                //     ),
                //   ),
                // ),
                const SizedBox(height: 40),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(status, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 20),
                  if (bondedDevices.isNotEmpty)
                    ...bondedDevices.map((device) {
                      return ElevatedButton(
                        onPressed: () => _connectToDevice(device),
                        child: Text("Connect to ${device.name}"),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget number(String label, VoidCallback onPressed, double width, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: width,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color.fromARGB(255, 0, 150, 50)
                : const Color.fromARGB(255, 80, 80, 80),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Poppins',
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}