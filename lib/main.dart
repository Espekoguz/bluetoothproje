import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  // Konum izni (Android için gereklidir)
  var status = await Permission.location.status;
  if (!status.isGranted) {
    await Permission.location.request();
  }

}
Future<void> requestBluetoothPermissions() async {
  // Gerekli tüm Bluetooth izinleri
  List<Permission> permissions = [
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
  ];

  // İzin durumlarını kontrol et
  Map<Permission, PermissionStatus> statuses = await permissions.request();

  // İzin durumlarını log'la
  statuses.forEach((permission, permissionStatus) {
    print('$permission: $permissionStatus');
  });
}

class BluetoothConnectPage extends StatefulWidget {
  @override
  _BluetoothConnectPageState createState() => _BluetoothConnectPageState();
}

class _BluetoothConnectPageState extends State<BluetoothConnectPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _device;
  bool _connected = false;
  List<String> receivedData =
      List.filled(7, ""); // Bluetooth'tan alınan veriler için

  List<String> dataNames = [
    "giren_amper",
    "giren_voltaj",
    "giren_guc",
    "cikan_amper",
    "cikan_voltaj",
    "cikan_guc",
    "Enerji"
  ]; // 7 veri için isimler

  @override
  void initState() {
    super.initState();
    requestBluetoothPermissions(); // Uygulama başladığında Bluetooth izinlerini iste
    requestPermissions();
    getBluetooth();
  }

  getBluetooth() async {
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    _bluetooth.onStateChanged().listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        getPairedDevices();
      });
    });
  }

  getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    try {
      devices = await _bluetooth.getBondedDevices();
    } on Exception {
      print('Error');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _devicesList = devices;
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await FlutterBluetoothSerial.instance
          .connect(device)
          .timeout(Duration(seconds: 10), onTimeout: () {
        // Bağlantı zaman aşımına uğrarsa
        print("Bağlantı zaman aşımına uğradı");
        return;
      }).then((connection) {
        print("Bağlandı: ${device.name}");
        setState(() {
          _connected = true;
          _device = device;
        });
      });
    } catch (e) {
      print("Bağlantı hatası: $e");
      setState(() {
        _connected = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Cihazları'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _devicesList.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = _devicesList[index];
                String deviceName = device.name ?? 'Bilinmeyen Cihaz';

                return ListTile(
                  onTap: () async {
                    connectToDevice(
                        device); // Bağlantı kurma fonksiyonunu çağır
                  },
                  title: Text(deviceName),
                  subtitle: Text(device.address),
                );
              },
            ),
          ),
          SwitchListTile(
            title: Text('Cihazı Aç/Kapat'),
            value: _connected,
            onChanged: (value) {
              setState(() {
                _connected = value;
                // Burada Bluetooth cihazını açıp kapatmak için gerekli işlemleri yapabilirsiniz.
              });
            },
          ),
          Text('Durum: ${_connected ? "Açık" : "Kapalı"}'),
          Text('Durum: ${_connected ? "Açık" : "Kapalı"}'),
          Expanded(
            child: ListView.builder(
              itemCount: dataNames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(dataNames[index]),
                  trailing: Text(receivedData[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void main() => runApp(MaterialApp(home: BluetoothConnectPage()));
