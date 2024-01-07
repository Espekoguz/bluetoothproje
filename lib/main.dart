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

    if (_bluetoothState == BluetoothState.STATE_OFF) {
      // Bluetooth kapalıysa, kullanıcıya açmasını teklif et
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Bluetooth Kapalı"),
            content: Text("Bluetooth'u açmak ister misiniz?"),
            actions: <Widget>[
              TextButton(
                child: Text("Evet"),
                onPressed: () async {
                  // Bluetooth'u aç
                  await FlutterBluetoothSerial.instance.requestEnable();
                  Navigator.of(context).pop();
                  getPairedDevices(); // Bluetooth açıldıktan sonra eşleştirilmiş cihazları al
                },
              ),
              TextButton(
                child: Text("Hayır"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      getPairedDevices(); // Bluetooth zaten açıksa, doğrudan eşleştirilmiş cihazları al
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
      print('Eşleştirilmiş cihazları alırken hata oluştu');
    }

    if (!mounted) return;

    setState(() {
      _devicesList = devices;
    });

    // Eşleştirilmiş cihaz yoksa bir hata mesajı göster
    if (_devicesList.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Eşleştirilmiş Cihaz Bulunamadı"),
            content: Text("Lütfen bir Bluetooth cihazı ile eşleştirin."),
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
    } else {
      // Eşleştirilmiş cihazlar varsa, bu noktada istenilen işlemleri yapabilirsiniz
    }
  }


  connectToDevice(BluetoothDevice device) async {
    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
      print('Cihaza bağlandı: ${device.name}');

      setState(() {
        _connected = true;
        _device = device;
      });

      // Bağlantı başarılı olduktan sonra '1' komutunu gönder
      connection.output.add(utf8.encode("1"));
      await connection.output.allSent;

      int dataIndex = 0; // Gelen verinin indeksi

      connection.input?.listen((Uint8List data) {
        String receivedString = ascii.decode(data);
        print('Gelen veri: $receivedString');

        List<String> splittedData = receivedString.split('\n');
        for (var dataPiece in splittedData) {
          if (dataPiece.isNotEmpty) {
            setState(() {
              // Gelen veriyi uygun indekse ekle
              receivedData[dataIndex] = dataPiece;
              dataIndex++;

              // Eğer 7 veri alındıysa, indeksi sıfırla
              if (dataIndex >= 7) {
                dataIndex = 0;
              }
            });
          }
        }

        if (receivedString.contains('!')) {
          connection.finish(); // Bağlantıyı kapat
          print('Yerel sunucu tarafından bağlantı kesiliyor');
          setState(() {
            _connected = false;
          });
        }
      }).onDone(() {
        print('Uzak istek tarafından bağlantı kesildi');
        setState(() {
          _connected = false;
        });
      });
    } catch (exception) {
      print('Bağlantı kurulamadı, hata oluştu: $exception');
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
          Expanded(
            child: ListView.builder(
              itemCount: receivedData.length,
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
