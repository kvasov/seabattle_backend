import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conduit_core/conduit_core.dart';

/// Контроллер для управления WebSocket соединениями.
///
/// Обеспечивает двустороннюю связь между клиентами и сервером для
/// передачи обновлений игры в реальном времени. Поддерживает фильтрацию
/// клиентов по ID игры и автоматическое закрытие неактивных соединений.
class GameWSController extends Controller {
  /// Список активных WebSocket клиентов.
  static final List<_WsClient> _clients = [];

  /// Таймаут неактивности в секундах.
  ///
  /// Если клиент не отправляет и не получает сообщения в течение этого времени,
  /// соединение будет закрыто.
  static const int _idleTimeoutSeconds = 300;

  /// Интервал проверки неактивных соединений в секундах.
  static const int _cleanupIntervalSeconds = 30;

  /// Таймер для периодической очистки неактивных соединений.
  static Timer? _cleanupTimer;

  /// Обрабатывает HTTP запросы и выполняет upgrade до WebSocket соединения.
  ///
  /// Если запрос направлен на путь `/ws` и является WebSocket upgrade запросом,
  /// создает новое WebSocket соединение и добавляет клиента в список активных соединений.
  ///
  /// [request] - HTTP запрос от клиента.
  /// Возвращает [Response] с кодом 200 при успешном upgrade или 404 для других путей.
  @override
  Future<RequestOrResponse> handle(Request request) async {
    if (request.raw.uri.path.endsWith('/ws')) {
      if (WebSocketTransformer.isUpgradeRequest(request.raw)) {
        // ignore: close_sinks
        final socket = await WebSocketTransformer.upgrade(request.raw);

        int? gameIdFilter;

        final client = _WsClient(socket, gameIdFilter);
        _clients.add(client);

        // Запускаем периодическую очистку неактивных соединений
        _startCleanupTimer();

        // Отслеживаем закрытие сокета для явного управления ресурсами
        // Сокет будет закрыт через _closeClient() в onDone/onError или при таймауте
        unawaited(
          socket.done.then((_) {
            _closeClient(client);
          }).catchError((error) {
            print('🧲 Ошибка WebSocket: $error');
            _closeClient(client);
          }),
        );

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
          _closeClient(client);
        },
        onError: (error) {
          print('🧲 Ошибка WebSocket: $error');
          _closeClient(client);
        });

        // После upgrade не возвращаем Response, так как соединение уже обновлено до WebSocket
        // Используем специальный ответ для Conduit
        return Response(200, null, null);
      }
    }
    return Response.notFound();
  }

  /// Запускает периодическую проверку и закрытие неактивных соединений.
  ///
  /// Если таймер уже запущен, метод ничего не делает. Таймер проверяет
  /// активность всех клиентов каждые [_cleanupIntervalSeconds] секунд и закрывает
  /// соединения, которые неактивны более [_idleTimeoutSeconds] секунд.
  static void _startCleanupTimer() {
    if (_cleanupTimer != null && _cleanupTimer!.isActive) {
      return;
    }

    _cleanupTimer = Timer.periodic(
      const Duration(seconds: _cleanupIntervalSeconds),
      (timer) {
        final now = DateTime.now();
        final clientsToRemove = <_WsClient>[];

        for (final client in _clients) {
          final idleDuration = now.difference(client.lastActivity).inSeconds;

          if (idleDuration > _idleTimeoutSeconds) {
            print('🧲 Закрытие неактивного соединения (неактивность: ${idleDuration}с)');
            clientsToRemove.add(client);
          }
        }

        clientsToRemove.forEach(_closeClient);

        if (clientsToRemove.isNotEmpty) {
          print('🧲 Удалено неактивных соединений: ${clientsToRemove.length}');
        }
      },
    );
  }

  /// Безопасно закрывает соединение и удаляет клиента из списка.
  ///
  /// Закрывает WebSocket соединение, если оно еще не закрыто, и удаляет
  /// клиента из списка активных соединений. Ошибки при закрытии обрабатываются
  /// и не прерывают выполнение.
  ///
  /// [client] - клиент, соединение которого нужно закрыть.
  static void _closeClient(_WsClient client) {
    try {
      // Закрываем сокет только если он еще не закрыт
      if (client.socket.closeCode == null) {
        client.socket.close();
      }
    } catch (e) {
      print('Ошибка при закрытии сокета: $e');
    } finally {
      _clients.remove(client);
    }
  }

  /// Рассылает информацию об обновлении игры подключенным клиентам.
  ///
  /// Отправляет сообщение об обновлении игры только тем клиентам, чей
  /// фильтр по ID игры совпадает с переданным [id]. Клиенты с ошибками
  /// отправки автоматически удаляются из списка активных соединений.
  ///
  /// [id] - ID игры, для которой произошло обновление.
  /// [mode] - режим обновления ('cancelled' или 'accepted').
  /// [userUniqueId] - уникальный идентификатор пользователя, инициировавшего обновление.
  /// нужен для того, чтобы клиент, который отправил запрос на обновление игры,
  /// получил сообщение об обновлении игры, но не обрабатывал его.
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
    clientsToRemove.forEach(_closeClient);
  }

  /// Рассылает информацию о размещении кораблей подключенным клиентам.
  ///
  /// Отправляет данные о кораблях только тем клиентам, чей фильтр по ID игры
  /// совпадает с переданным [id]. Клиенты с ошибками отправки автоматически
  /// удаляются из списка активных соединений.
  ///
  /// [id] - ID игры, для которой отправляются корабли.
  /// [userUniqueId] - уникальный идентификатор пользователя, отправившего корабли.
  /// [ships] - список кораблей в формате Map с координатами и размерами.
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
    clientsToRemove.forEach(_closeClient);
  }

  /// Рассылает информацию о выстреле подключенным клиентам.
  ///
  /// Отправляет данные о выстреле только тем клиентам, чей фильтр по ID игры
  /// совпадает с переданным [id]. Клиенты с ошибками отправки автоматически
  /// удаляются из списка активных соединений.
  ///
  /// [id] - ID игры, для которой выполнен выстрел.
  /// [userUniqueId] - уникальный идентификатор пользователя, выполнившего выстрел.
  /// [x] - координата X выстрела.
  /// [y] - координата Y выстрела.
  /// [isHit] - флаг, указывающий, попал ли выстрел в корабль.
  static void broadcastSendShot(int id, String userUniqueId, int x, int y, {required bool isHit}) {
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
    clientsToRemove.forEach(_closeClient);
  }
}

/// Внутренний класс для представления WebSocket клиента.
///
/// Хранит информацию о WebSocket соединении, фильтре по ID игры
/// и времени последней активности клиента.
class _WsClient {
  /// Создает новый экземпляр WebSocket клиента.
  ///
  /// [socket] - WebSocket соединение с клиентом.
  /// [gameIdFilter] - фильтр по ID игры (может быть null до получения первого сообщения).
  _WsClient(this.socket, this.gameIdFilter) : lastActivity = DateTime.now();

  /// WebSocket соединение с клиентом.
  final WebSocket socket;

  /// Фильтр по ID игры для отправки сообщений только нужным клиентам.
  ///
  /// Может быть null до получения первого сообщения от клиента с gameId.
  int? gameIdFilter;

  /// Время последней активности клиента (получение или отправка сообщения).
  DateTime lastActivity;

  @override
  String toString() {
    return '_WsClient(filter: $gameIdFilter, socket: $socket, lastActivity: $lastActivity)';
  }
}