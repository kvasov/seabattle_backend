import 'dart:io';
import 'package:conduit_core/conduit_core.dart';
import 'package:seabattle_app/controller/game_websocket_controller.dart';
import 'package:seabattle_app/validator/game_validator.dart';

/// Контроллер для отправки информации о размещении кораблей сопернику.
///
/// Обрабатывает запросы на отправку данных о кораблях и рассылает их
/// всем подключенным клиентам через WebSocket соединение.
class SendShipsToOpponentController extends ResourceController {
  /// Создает новый экземпляр контроллера отправки кораблей.
  ///
  /// [context] - контекст базы данных (используется для совместимости с базовым классом).
  SendShipsToOpponentController(this.context);

  /// Контекст базы данных.
  final ManagedContext context;

  /// Отправляет информацию о кораблях сопернику через WebSocket.
  ///
  /// Принимает данные о кораблях из тела запроса и рассылает их всем
  /// подключенным клиентам, подписанным на указанную игру.
  ///
  /// [id] - ID игры, для которой отправляются корабли.
  /// [body] - тело запроса, должно содержать 'ships' (список кораблей) и 'userUniqueId'.
  /// Возвращает [Response] с подтверждением отправки или ошибку сервера.
  @Operation.post('id')
  Future<Response> sendShipsToOpponent(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {
    try {
      print("sendShipsToOpponent raw request body: $body");
      print("sendShipsToOpponent controller called with id: $id");

      // Проверка наличия обязательных полей
      if (!body.containsKey('ships') || !body.containsKey('userUniqueId')) {
        return Response.badRequest(
          body: {'error': 'Отсутствуют обязательные поля: ships, userUniqueId'}
        )..contentType = ContentType.json;
      }

      // Проверка типа данных ships
      final shipsData = body['ships'];
      if (shipsData is! List) {
        return Response.badRequest(
          body: {'error': 'Поле ships должно быть массивом, получено: ${shipsData.runtimeType}'}
        )..contentType = ContentType.json;
      }

      // Проверка типа данных userUniqueId
      final userUniqueId = body['userUniqueId'];
      if (userUniqueId is! String || userUniqueId.isEmpty) {
        return Response.badRequest(
          body: {'error': 'Поле userUniqueId должно быть непустой строкой'}
        )..contentType = ContentType.json;
      }

      // Преобразование списка в List<Map<String, dynamic>>
      final ships = <Map<String, dynamic>>[];
      for (int i = 0; i < shipsData.length; i++) {
        final ship = shipsData[i];
        if (ship is! Map) {
          return Response.badRequest(
            body: {'error': 'Корабль #${i + 1} должен быть объектом, получено: ${ship.runtimeType}'}
          )..contentType = ContentType.json;
        }
        ships.add(Map<String, dynamic>.from(ship));
      }

      // Валидация расстановки кораблей
      final validationError = validateShipsPlacement(ships);
      if (validationError != null) {
        return Response.badRequest(
          body: {'error': validationError}
        )..contentType = ContentType.json;
      }

      GameWSController.broadcastSendShips(id, userUniqueId, ships);

      return Response.ok({'message': 'Корабли отправлены сопернику'})..contentType = ContentType.json;
    } catch (e) {
      return Response.serverError(body: {'error': e.toString()});
    }
  }
}
