import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conduit_core/conduit_core.dart';


class GameWSController extends Controller {
  static final List<_WsClient> _clients = [];

  // Таймаут неактивности в секундах
  static const int _idleTimeoutSeconds = 300;

  // Интервал проверки неактивных соединений в секундах
  static const int _cleanupIntervalSeconds = 30;

  static Timer? _cleanupTimer;

  @override
  Future<RequestOrResponse> handle(Request request) async {
    if (request.raw.uri.path.endsWith('/ws')) {
      if (WebSocketTransformer.isUpgradeRequest(request.raw)) {
        final socket = await WebSocketTransformer.upgrade(request.raw);

        int? gameIdFilter;

        final client = _WsClient(socket, gameIdFilter);
        _clients.add(client);

        // Запускаем периодическую очистку неактивных соединений
        _startCleanupTimer();

        socket.listen((message) {
          print('🧲 Connected to WebSocket, message: $message');
          // Обновляем время последней активности
          client.lastActivity = DateTime.now();

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
        onDone: () {
          print('🧲 WebSocket соединение закрыто');
          _clients.remove(client);
        },
        onError: (error) {
          print('🧲 Ошибка WebSocket: $error');
          _clients.remove(client);
        });

        // После upgrade не возвращаем Response, так как соединение уже обновлено до WebSocket
        // Используем специальный ответ для Conduit
        return Response(200, null, null);
      }
    }
    return Response.notFound();
  }

  // Запускает периодическую проверку и закрытие неактивных соединений
  static void _startCleanupTimer() {
    if (_cleanupTimer != null && _cleanupTimer!.isActive) {
      return;
    }

    _cleanupTimer = Timer.periodic(
      Duration(seconds: _cleanupIntervalSeconds),
      (timer) {
        final now = DateTime.now();
        final clientsToRemove = <_WsClient>[];

        for (final client in _clients) {
          final idleDuration = now.difference(client.lastActivity).inSeconds;

          if (idleDuration > _idleTimeoutSeconds) {
            print('🧲 Закрытие неактивного соединения (неактивность: ${idleDuration}с)');
            clientsToRemove.add(client);
            try {
              client.socket.close();
            } catch (e) {
              print('Ошибка при закрытии сокета: $e');
            }
          }
        }

        for (final client in clientsToRemove) {
          _clients.remove(client);
        }

        if (clientsToRemove.isNotEmpty) {
          print('🧲 Удалено неактивных соединений: ${clientsToRemove.length}');
        }
      },
    );
  }

  // Рассылаем информацию об обновлении игры
  // только тому клиенту, чей фильтр совпадает с id игры
  static void broadcastUpdateGame(int id, String mode, String userUniqueId) {
    print('🧲 broadcastUpdateGame: $id, $mode, $userUniqueId');
    final data = '{"id":${id},"mode":"${mode}","userUniqueId":"${userUniqueId}"}';

    final clientsToRemove = <_WsClient>[];

    for (final client in _clients) {
      final gameIdFilter = client.gameIdFilter;
      print('Client filter: $gameIdFilter, id: $id');

      if (gameIdFilter != null && gameIdFilter == id) {
        try {
          client.socket.add(data);
          client.lastActivity = DateTime.now();
        } catch (e) {
          print('Ошибка отправки сообщения клиенту: $e');
          clientsToRemove.add(client);
        }
      }
    }

    // Удаляем клиентов с ошибками
    for (final client in clientsToRemove) {
      _clients.remove(client);
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

    final clientsToRemove = <_WsClient>[];

    for (final client in _clients) {
      final gameIdFilter = client.gameIdFilter;
      print('Client filter: $gameIdFilter, id: $id');

      if (gameIdFilter != null && gameIdFilter == id) {
        try {
          client.socket.add(dataJson);
          client.lastActivity = DateTime.now();
        } catch (e) {
          print('Ошибка отправки сообщения клиенту: $e');
          clientsToRemove.add(client);
        }
      }
    }

    // Удаляем клиентов с ошибками
    for (final client in clientsToRemove) {
      _clients.remove(client);
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

    final clientsToRemove = <_WsClient>[];

    for (final client in _clients) {
      final gameIdFilter = client.gameIdFilter;
      print('Client filter: $gameIdFilter, id: $id');

      if (gameIdFilter != null && gameIdFilter == id) {
        try {
          client.socket.add(dataJson);
          client.lastActivity = DateTime.now();
        } catch (e) {
          print('Ошибка отправки сообщения клиенту: $e');
          clientsToRemove.add(client);
        }
      }
    }

    // Удаляем клиентов с ошибками
    for (final client in clientsToRemove) {
      _clients.remove(client);
    }
  }
}

class _WsClient {
  _WsClient(this.socket, this.gameIdFilter) : lastActivity = DateTime.now();

  final WebSocket socket;
  int? gameIdFilter;
  DateTime lastActivity; // Время последней активности (получение или отправка сообщения)

  @override
  String toString() {
    return '_WsClient(filter: $gameIdFilter, socket: $socket, lastActivity: $lastActivity)';
  }
}