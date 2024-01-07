import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:typed_data';

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
  late BluetoothDevice _device;
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
    requestPermissions().then((_) {
      requestBluetoothPermissions().then((_) {
        // İzinler verildikten sonra Bluetooth durumunu ve eşleştirilmiş cihazları al
        getBluetooth();
      });
    });
  }


  getBluetooth() async {
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    if (_bluetoothState != BluetoothState.STATE_ON) {
      // Bluetooth kapalıysa, kullanıcıya uyarı göster
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Bluetooth Kapalı"),
            content: Text("Lütfen Bluetooth'u açın."),
            actions: <Widget>[
              TextButton(
                child: Text("Tamam"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

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
      BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
      print('Cihaza bağlandı: ${device.name}');

      connection.input?.listen((Uint8List data) {
        print('Gelen veri: ${ascii.decode(data)}');
        // Gelen veriyi işleme veya yanıtlama

        if (ascii.decode(data).contains('!')) {
          connection.finish(); // Bağlantıyı kapat
          print('Yerel sunucu tarafından bağlantı kesiliyor');
        }
      }).onDone(() {
        print('Uzak istek tarafından bağlantı kesildi');
      });
    }
    catch (exception) {
      print('Bağlantı kurulamadı, hata oluştu: $exception');
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
