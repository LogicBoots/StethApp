import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class StethBluetoothService {
  static const String targetDeviceAddress = "30:C6:F7:30:70:FA";
  static const int samplingRate = 8000;
  static const int minValue = -32768;
  static const int maxValue = 32768;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _dataCharacteristic;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _characteristicSubscription;

  final StreamController<List<double>> _audioDataController =
      StreamController<List<double>>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  Stream<List<double>> get audioDataStream => _audioDataController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _connectedDevice != null;

  final List<int> _buffer = [];
  final List<double> _normalizedBuffer = [];

  /// Request necessary permissions for Bluetooth
  Future<bool> requestPermissions() async {
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted &&
        await Permission.location.request().isGranted) {
      return true;
    }
    return false;
  }

  /// Connect to the stethoscope device
  Future<bool> connectToStethoscope() async {
    try {
      // Check if Bluetooth is available and on
      if (await FlutterBluePlus.isAvailable == false) {
        print("Bluetooth not available");
        return false;
      }

      // Request permissions
      if (!await requestPermissions()) {
        print("Bluetooth permissions not granted");
        return false;
      }

      // Check if already connected
      if (_connectedDevice != null) {
        print("Already connected to device");
        return true;
      }

      print("Starting scan for device: $targetDeviceAddress");

      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Listen to scan results
      BluetoothDevice? targetDevice;
      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.remoteId.toString().toUpperCase() ==
              targetDeviceAddress.toUpperCase()) {
            targetDevice = result.device;
            print("Found target device: ${result.device.remoteId}");
            FlutterBluePlus.stopScan();
            break;
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await scanSubscription.cancel();
      await FlutterBluePlus.stopScan();

      if (targetDevice == null) {
        print("Device not found");
        return false;
      }

      // Connect to device
      print("Connecting to device...");
      await targetDevice!.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = targetDevice;

      // Listen to connection state
      _deviceStateSubscription =
          targetDevice!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _connectionStateController.add(true);
          print("Device connected");
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectionStateController.add(false);
          print("Device disconnected");
          _cleanup();
        }
      });

      // Discover services
      print("Discovering services...");
      final services = await targetDevice!.discoverServices();

      // Find the characteristic that sends audio data
      // You may need to adjust these UUIDs based on your stethoscope's specifications
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            _dataCharacteristic = characteristic;
            print(
                "Found notify characteristic: ${characteristic.uuid}");

            // Subscribe to notifications
            await characteristic.setNotifyValue(true);
            _characteristicSubscription =
                characteristic.lastValueStream.listen((value) {
              _processIncomingData(value);
            });

            break;
          }
        }
        if (_dataCharacteristic != null) break;
      }

      if (_dataCharacteristic == null) {
        print("No suitable characteristic found");
        await disconnect();
        return false;
      }

      print("Successfully connected and subscribed to data");
      return true;
    } catch (e) {
      print("Error connecting to stethoscope: $e");
      await disconnect();
      return false;
    }
  }

  /// Process incoming Bluetooth data
  void _processIncomingData(List<int> data) {
    try {
      // Add incoming bytes to buffer
      _buffer.addAll(data);

      // Process complete samples (assuming 16-bit signed integers = 2 bytes per sample)
      while (_buffer.length >= 2) {
        // Extract 2 bytes and convert to signed 16-bit integer
        int byte1 = _buffer.removeAt(0);
        int byte2 = _buffer.removeAt(0);

        // Combine bytes (little-endian)
        int rawValue = (byte2 << 8) | byte1;

        // Convert to signed value
        if (rawValue > 32767) {
          rawValue = rawValue - 65536;
        }

        // Normalize to [-1.0, 1.0]
        double normalized = rawValue / 32768.0;
        _normalizedBuffer.add(normalized);

        // Send chunks of data for processing (e.g., every 100 samples)
        if (_normalizedBuffer.length >= 100) {
          _audioDataController.add(List<double>.from(_normalizedBuffer));
          _normalizedBuffer.clear();
        }
      }
    } catch (e) {
      print("Error processing incoming data: $e");
    }
  }

  /// Get a buffer of audio data for model input
  Future<List<double>> getAudioBuffer(int sampleCount) async {
    final completer = Completer<List<double>>();
    final buffer = <double>[];

    StreamSubscription? subscription;
    subscription = audioDataStream.listen((data) {
      buffer.addAll(data);

      if (buffer.length >= sampleCount) {
        subscription?.cancel();
        completer.complete(buffer.sublist(0, sampleCount));
      }
    });

    // Timeout after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.completeError('Timeout waiting for audio data');
      }
    });

    return completer.future;
  }

  /// Disconnect from the device
  Future<void> disconnect() async {
    try {
      await _characteristicSubscription?.cancel();
      await _deviceStateSubscription?.cancel();
      
      if (_dataCharacteristic != null) {
        try {
          await _dataCharacteristic!.setNotifyValue(false);
        } catch (e) {
          print("Error disabling notifications: $e");
        }
      }

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      _cleanup();
      print("Disconnected from device");
    } catch (e) {
      print("Error disconnecting: $e");
      _cleanup();
    }
  }

  void _cleanup() {
    _connectedDevice = null;
    _dataCharacteristic = null;
    _buffer.clear();
    _normalizedBuffer.clear();
  }

  void dispose() {
    _audioDataController.close();
    _connectionStateController.close();
    _characteristicSubscription?.cancel();
    _deviceStateSubscription?.cancel();
  }
}
