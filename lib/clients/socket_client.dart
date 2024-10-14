import 'package:google_doc_clone/constants.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketClient {
  io.Socket? socket;
  static SocketClient? _instance;

  SocketClient._internal() {
    try {
      socket = io.io(host, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });
      socket!.connect();
      print('Socket connected to $host');
    } catch (e) {
      print('Error connecting to socket: $e');
    }
  }

  static SocketClient get instance {
    _instance ??= SocketClient._internal();
    return _instance!;
  }
}
