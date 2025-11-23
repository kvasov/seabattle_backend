import 'dart:io';
import 'package:conduit_core/conduit_core.dart';
import 'package:seabattle_app/controller/game_websocket_controller.dart';
import 'package:seabattle_app/model/game.dart';

abstract class GameUpdateController extends ResourceController {
  GameUpdateController(this.context);

  final ManagedContext context;

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

      print("game: id=${game.id}, cancelled=${game.cancelled}, accepted=${game.accepted}, completed=${game.completed}");

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
        case 'completed':
          updateQuery.values.completed = true;
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
        'completed': updatedGame.completed,
        'createdAt': updatedGame.createdAt?.toIso8601String()
      })..contentType = ContentType.json;
    } catch (e) {
      return Response.serverError(body: {'error': e.toString()});
    }
  }
}

class CancelGameController extends GameUpdateController {
  CancelGameController(super.context);

  @Operation.post('id')
  Future<Response> cancelGame(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {
    print("cancelGame raw request body: $body");
    print("cancelGame controller called with id: $id");
    return await updateGameField(id, 'cancelled', body['userUniqueId']);
  }
}

class AcceptGameController extends GameUpdateController {
  AcceptGameController(super.context);

  @Operation.post('id')
  Future<Response> acceptGame(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {

    print("acceptGame raw request body: $body");
    print("acceptGame controller called with id: $id");
    return await updateGameField(id, 'accepted', body['userUniqueId']);
  }
}

class CompleteGameController extends GameUpdateController {
  CompleteGameController(super.context);

  @Operation.post('id')
  Future<Response> completeGame(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {
    print("completeGame raw request body: $body");
    print("completeGame controller called with id: $id");
    return await updateGameField(id, 'completed', body['userUniqueId']);
  }
}
