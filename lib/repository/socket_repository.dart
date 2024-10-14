import 'package:google_doc_clone/clients/socket_client.dart';
import 'package:socket_io_client/socket_io_client.dart';

class SocketRepository {
  final _socketClient = SocketClient.instance.socket!;

  Socket get socketClient => _socketClient;

  void joinRoom(String documentId) {
    try {
      _socketClient.emit('join', documentId);
      print('Joined room: $documentId');
    } catch (e) {
      print('Error joining room: $e');
    }
  }

  void typing(Map<String, dynamic> data) {
    try {
      _socketClient.emit('typing', data);
      print('Typing event emitted: $data');
    } catch (e) {
      print('Error emitting typing event: $e');
    }
  }

  void autoSave(Map<String, dynamic> data) {
    try {
      _socketClient.emit('save', data);
      print('Auto-save event emitted: $data');
    } catch (e) {
      print('Error emitting auto-save event: $e');
    }
  }

  void changeListener(Function(Map<String, dynamic>) func) {
    _socketClient.on("changes", (data) {
      print('Change event received: $data');
      func(data); // Return the result of func
    });
  }
}
