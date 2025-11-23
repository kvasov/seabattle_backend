import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conduit_core/conduit_core.dart';


class GameWSController extends Controller {
  static final List<_WsClient> _clients = [];

  @override
  Future<RequestOrResponse> handle(Request request) async {
    if (request.raw.uri.path.endsWith('/ws')) {
      if (WebSocketTransformer.isUpgradeRequest(request.raw)) {
        final socket = await WebSocketTransformer.upgrade(request.raw);

        int? gameIdFilter;

        final client = _WsClient(socket, gameIdFilter);
        _clients.add(client);

        socket.listen((message) {
          print('🧲 Connected to WebSocket, message: $message');
          if (gameIdFilter == null) {
            try {
              gameIdFilter = jsonDecode(message)['gameId'] as int;
              print('🧲 gameIdFilter: $gameIdFilter');
              client.gameIdFilter = gameIdFilter;
            } catch (e) {
              print('Ошибка парсинга gameId: $e');
            }
          }
        },
        onDone: () => _clients.remove(client),
        onError: (_) => _clients.remove(client));

        // После upgrade не возвращаем Response, так как соединение уже обновлено до WebSocket
        // Используем специальный ответ для Conduit
        return Response(200, null, null);
      }
    }
    return Response.notFound();
  }

  // Рассылаем информацию об обновлении игры
  // только тому клиенту, чей фильтр совпадает с id игры
  static void broadcastUpdateGame(int id, String mode, String userUniqueId) {
    print('🧲 broadcastUpdateGame: $id, $mode, $userUniqueId');
    final data = '{"id":${id},"mode":"${mode}","userUniqueId":"${userUniqueId}"}';

    for (final client in _clients) {
      final gameIdFilter = client.gameIdFilter;
      print('Client filter: $gameIdFilter, id: $id');

      if (gameIdFilter != null && gameIdFilter == id) {
        client.socket.add(data);
      }
    }
  }

  static void broadcastSendShips(int id, String userUniqueId, List<Map<String, dynamic>> ships) {
    print('🧲 broadcastSendShips: $id, $userUniqueId, $ships');
    final dataJson = jsonEncode(
      {
        'id': id,
        'userUniqueId': userUniqueId,
        'ships': ships
      }
    );
    for (final client in _clients) {
      final gameIdFilter = client.gameIdFilter;
      print('Client filter: $gameIdFilter, id: $id');

      if (gameIdFilter != null && gameIdFilter == id) {
        client.socket.add(dataJson);
      }
    }
  }

  static void broadcastSendShot(int id, String userUniqueId, int x, int y, bool isHit) {
    print('🧲 broadcastSendShot: $id, $userUniqueId, $x, $y');
    final dataJson = jsonEncode(
      {
        'type': 'shot',
        'id': id,
        'userUniqueId': userUniqueId,
        'x': x,
        'y': y,
        'isHit': isHit
      }
    );
    for (final client in _clients) {
      final gameIdFilter = client.gameIdFilter;
      print('Client filter: $gameIdFilter, id: $id');

      if (gameIdFilter != null && gameIdFilter == id) {
        client.socket.add(dataJson);
      }
    }
  }
}

class _WsClient {
  _WsClient(this.socket, this.gameIdFilter);

  final WebSocket socket;
  int? gameIdFilter;

  @override
  String toString() {
    return '_WsClient(filter: $gameIdFilter, socket: $socket)';
  }
}