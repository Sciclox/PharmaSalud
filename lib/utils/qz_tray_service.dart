import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class QZTrayService {
  static const String _host = 'localhost';
  static const List<int> _ports = [8182, 8283, 8384, 8485, 4242];

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connected = false;
  bool _setupComplete = false;

  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _requestId = 0;

  bool get isConnected => _connected && _setupComplete;

  Future<bool> isAvailable() async {
    try {
      await connect();
      disconnect();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect() async {
    if (_connected) return;

    for (final port in _ports) {
      try {
        final uri = Uri.parse('ws://$_host:$port');
        debugPrint('QZ Tray: Trying $uri');
        _channel = WebSocketChannel.connect(uri);
        await _channel!.ready;
        _connected = true;

        _subscription = _channel!.stream.listen(
          _onMessage,
          onError: _onError,
          onDone: _onDone,
        );

        await _performHandshake();
        debugPrint('QZ Tray: Connected on port $port');
        return;
      } catch (e) {
        debugPrint('QZ Tray: Port $port failed: $e');
        _channel = null;
        _connected = false;
      }
    }

    throw Exception(
        'No se pudo conectar con QZ Tray. Asegúrate de que QZ Tray esté ejecutándose.');
  }

  Future<void> _performHandshake() async {
    final version = await _sendRequest('getVersion');
    debugPrint('QZ Tray: Version $version');
    await _sendRaw({'certificate': null});
    _setupComplete = true;
    debugPrint('QZ Tray: Handshake complete');
  }

  void disconnect() {
    _setupComplete = false;
    _connected = false;
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _pendingRequests.clear();
  }

  Future<List<String>> listPrinters({String? query}) async {
    await _ensureConnected();
    final result = await _sendRequest('printers.find',
        params: query != null ? {'query': query} : {});
    return List<String>.from(result as List);
  }

  Future<bool> printPdf(Uint8List pdfData, {String? printerName}) async {
    await _ensureConnected();

    String printer;
    if (printerName != null && printerName.isNotEmpty) {
      printer = printerName;
    } else {
      final printers = await listPrinters();
      printer = _findBestPrinter(printers);
    }

    final base64Data = base64Encode(pdfData);

    debugPrint('QZ Tray: Printing to "$printer"');
    debugPrint('QZ Tray: PDF size: ${pdfData.length} bytes');

    await _sendRequest('print', params: {
      'config': {'printer': printer},
      'data': [
        {
          'type': 'pdf',
          'format': 'base64',
          'flavor': 'base64',
          'data': base64Data,
        }
      ],
    });

    return true;
  }

  String _findBestPrinter(List<String> printers) {
    final keywords = [
      'EPSON',
      'TM-',
      'TICKET',
      'THERMAL',
      'ZEBRA',
      'STAR',
      'POS',
      'RECEIPT',
      'BEMATECH',
      'DARUMA',
    ];

    for (final keyword in keywords) {
      final matches =
          printers.where((p) => p.toUpperCase().contains(keyword)).toList();
      if (matches.isNotEmpty) {
        debugPrint('QZ Tray: Selected printer: ${matches.first}');
        return matches.first;
      }
    }

    if (printers.isNotEmpty) {
      debugPrint('QZ Tray: No thermal printer found, using: ${printers.first}');
      return printers.first;
    }

    throw Exception('No hay impresoras disponibles');
  }

  Future<void> _ensureConnected() async {
    if (!_connected || !_setupComplete) {
      await connect();
    }
  }

  String _generateUid() {
    _requestId++;
    return 'qz_dart_$_requestId';
  }

  Future<dynamic> _sendRequest(String method,
      {Map<String, dynamic>? params}) async {
    final uid = _generateUid();
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[uid] = completer;

    final message = {
      'call': method,
      'params': params ?? {},
      'uid': uid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'position': {'x': 0, 'y': 0},
    };

    final json = jsonEncode(message);
    debugPrint('QZ Tray: >> $json');
    _channel!.sink.add(json);

    final response = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(uid);
        throw TimeoutException(
            'QZ Tray no respondió en 30 segundos para: $method');
      },
    );

    if (response.containsKey('error') && response['error'] != null) {
      throw Exception('Error de QZ Tray: ${response['error']}');
    }

    return response['result'];
  }

  Future<dynamic> _sendRaw(Map<String, dynamic> data) async {
    final uid = _generateUid();
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[uid] = completer;

    data['uid'] = uid;
    data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    data['position'] = {'x': 0, 'y': 0};

    final json = jsonEncode(data);
    debugPrint('QZ Tray: >> $json');
    _channel!.sink.add(json);

    final response = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(uid);
        throw TimeoutException('QZ Tray no respondió en 30 segundos');
      },
    );

    if (response.containsKey('error') && response['error'] != null) {
      throw Exception('Error de QZ Tray: ${response['error']}');
    }

    return response['result'];
  }

  void _onMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data as String) as Map<String, dynamic>;
      debugPrint('QZ Tray: << $decoded');

      final uid = decoded['uid'] as String?;
      if (uid != null && _pendingRequests.containsKey(uid)) {
        final completer = _pendingRequests.remove(uid)!;
        completer.complete(decoded);
      } else {
        debugPrint('QZ Tray: Unhandled message: $decoded');
      }
    } catch (e) {
      debugPrint('QZ Tray: Error parsing message: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('QZ Tray: Error: $error');
    _connected = false;
    _setupComplete = false;
    for (final entry in _pendingRequests.entries) {
      entry.value.completeError(error);
    }
    _pendingRequests.clear();
  }

  void _onDone() {
    debugPrint('QZ Tray: Connection closed');
    _connected = false;
    _setupComplete = false;
    final error = Exception('Conexión con QZ Tray cerrada');
    for (final entry in _pendingRequests.entries) {
      entry.value.completeError(error);
    }
    _pendingRequests.clear();
  }

  void dispose() {
    disconnect();
  }
}
