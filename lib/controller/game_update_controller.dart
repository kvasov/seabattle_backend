import 'dart:io';
import 'package:conduit_core/conduit_core.dart';
import 'package:seabattle_app/controller/game_websocket_controller.dart';
import 'package:seabattle_app/model/game.dart';

/// Абстрактный базовый контроллер для обновления полей игры.
///
/// Предоставляет общую логику для обновления различных полей игры
/// (например, cancelled, accepted) с валидацией и уведомлением клиентов
/// через WebSocket о произошедших изменениях.
abstract class GameUpdateController extends ResourceController {
  /// Создает новый экземпляр контроллера обновления игры.
  ///
  /// [context] - контекст базы данных для выполнения операций с играми.
  GameUpdateController(this.context);

  /// Контекст базы данных для выполнения операций с играми.
  final ManagedContext context;

  /// Обновляет указанное поле игры в базе данных.
  ///
  /// Выполняет валидацию перед обновлением (например, проверяет, не была ли
  /// игра уже принята или отменена). После успешного обновления отправляет
  /// уведомление всем подключенным клиентам через WebSocket.
  ///
  /// Если [id] равен 0, используется ID последней созданной игры.
  ///
  /// [id] - ID игры для обновления (0 для последней игры).
  /// [fieldName] - имя поля для обновления ('cancelled' или 'accepted').
  /// [userUniqueId] - уникальный идентификатор пользователя, инициировавшего обновление.
  /// Возвращает [Response] с обновленными данными игры или ошибку.
  Future<Response> updateGameField(int id, String fieldName, String userUniqueId) async {
    try {
      // если id == 0, то берем последнюю игру из БД
      late int _id;
      if (id == 0) {
        final readQuery = Query<Game>(context)
          ..sortBy((g) => g.createdAt, QuerySortOrder.descending);
        final game = await readQuery.fetchOne();
        _id = game!.id!;
      } else {
        _id = id;
      }

      // Сначала читаем текущее состояние игры
      final readQuery = Query<Game>(context)
        ..where((g) => g.id).equalTo(_id);
      final game = await readQuery.fetchOne();

      if (game == null) {
        return Response.notFound(body: {'error': 'Игра с id $_id не найдена'});
      }

      print("game: id=${game.id}, cancelled=${game.cancelled}, accepted=${game.accepted}");

      // Проверки перед обновлением
      switch (fieldName) {
        case 'accepted':
          if (game.accepted == true) {
            return Response.ok({
              'id': game.id,
              'error': 'already_accepted',
            });
          }
          if (game.cancelled == true) {
            return Response.ok({
              'id': game.id,
              'error': 'cancelled',
            });
          }
          break;
        default:
          break;
      }

      // Создаем новый Query для обновления
      final updateQuery = Query<Game>(context)
        ..where((g) => g.id).equalTo(_id);

      switch (fieldName) {
        case 'cancelled':
          updateQuery.values.cancelled = true;
          break;
        case 'accepted':
          updateQuery.values.accepted = true;
          break;
        default:
          return Response.badRequest(body: {'error': 'Неизвестное поле'});
      }

      final updatedGame = await updateQuery.updateOne();

      if (updatedGame == null) {
        return Response.notFound(body: {'error': 'Игра с id $_id не найдена'});
      }

      switch (fieldName) {
        case 'cancelled':
          GameWSController.broadcastUpdateGame(updatedGame.id!, 'cancelled', userUniqueId);
          break;
        case 'accepted':
          GameWSController.broadcastUpdateGame(updatedGame.id!, 'accepted', userUniqueId);
          break;
      }

      return Response.ok({
        'id': updatedGame.id,
        'name': updatedGame.name,
        'cancelled': updatedGame.cancelled,
        'accepted': updatedGame.accepted,
        'createdAt': updatedGame.createdAt?.toIso8601String()
      })..contentType = ContentType.json;
    } catch (e) {
      return Response.serverError(body: {'error': e.toString()});
    }
  }
}

/// Контроллер для отмены игры.
///
/// Обрабатывает запросы на отмену игры, устанавливая поле cancelled в true.
class CancelGameController extends GameUpdateController {
  /// Создает новый экземпляр контроллера отмены игры.
  ///
  /// [context] - контекст базы данных для выполнения операций с играми.
  CancelGameController(super.context);

  /// Отменяет игру с указанным ID.
  ///
  /// Устанавливает поле cancelled в true для указанной игры и уведомляет
  /// всех подключенных клиентов через WebSocket.
  ///
  /// [id] - ID игры для отмены.
  /// [body] - тело запроса, должно содержать 'userUniqueId'.
  /// Возвращает [Response] с обновленными данными игры или ошибку.
  @Operation.post('id')
  Future<Response> cancelGame(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {
    print("cancelGame raw request body: $body");
    print("cancelGame controller called with id: $id");
    return await updateGameField(id, 'cancelled', body['userUniqueId']);
  }
}

/// Контроллер для принятия игры.
///
/// Обрабатывает запросы на принятие игры, устанавливая поле accepted в true.
class AcceptGameController extends GameUpdateController {
  /// Создает новый экземпляр контроллера принятия игры.
  ///
  /// [context] - контекст базы данных для выполнения операций с играми.
  AcceptGameController(super.context);

  /// Принимает игру с указанным ID.
  ///
  /// Устанавливает поле accepted в true для указанной игры и уведомляет
  /// всех подключенных клиентов через WebSocket. Выполняет проверку, что
  /// игра не была уже принята или отменена.
  ///
  /// [id] - ID игры для принятия.
  /// [body] - тело запроса, должно содержать 'userUniqueId'.
  /// Возвращает [Response] с обновленными данными игры или ошибку.
  @Operation.post('id')
  Future<Response> acceptGame(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {

    print("acceptGame raw request body: $body");
    print("acceptGame controller called with id: $id");
    return await updateGameField(id, 'accepted', body['userUniqueId']);
  }
}