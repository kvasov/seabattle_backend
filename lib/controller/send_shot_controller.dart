import 'dart:io';
import 'package:conduit_core/conduit_core.dart';
import 'package:seabattle_app/controller/game_websocket_controller.dart';
import 'package:seabattle_app/validator/game_validator.dart';

/// Контроллер для отправки информации о выстреле сопернику.
///
/// Обрабатывает запросы на отправку данных о выстреле и рассылает их
/// всем подключенным клиентам через WebSocket соединение.
class SendShotToOpponentController extends ResourceController {
  /// Создает новый экземпляр контроллера отправки выстрела.
  ///
  /// [context] - контекст базы данных (используется для совместимости с базовым классом).
  SendShotToOpponentController(this.context);

  /// Контекст базы данных.
  final ManagedContext context;

  /// Отправляет информацию о выстреле сопернику через WebSocket.
  ///
  /// Принимает данные о выстреле из тела запроса и рассылает их всем
  /// подключенным клиентам, подписанным на указанную игру.
  ///
  /// [id] - ID игры, для которой выполнен выстрел.
  /// [body] - тело запроса, должно содержать 'x', 'y', 'isHit' и 'userUniqueId'.
  /// Возвращает [Response] с подтверждением отправки или ошибку сервера.
  @Operation.post('id')
  Future<Response> sendShipsToOpponent(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {
    try {
      print("sendShipsToOpponent raw request body: $body");
      print("sendShipsToOpponent controller called with id: $id");

      // Проверка наличия обязательных полей
      if (!body.containsKey('x') || !body.containsKey('y') ||
          !body.containsKey('isHit') || !body.containsKey('userUniqueId')) {
        return Response.badRequest(
          body: {'error': 'Отсутствуют обязательные поля: x, y, isHit, userUniqueId'}
        )..contentType = ContentType.json;
      }

      // Проверка типов данных
      final xValue = body['x'];
      final yValue = body['y'];
      final isHitValue = body['isHit'];
      final userUniqueIdValue = body['userUniqueId'];

      if (xValue is! int) {
        return Response.badRequest(
          body: {'error': 'Поле x должно быть числом, получено: ${xValue.runtimeType}'}
        )..contentType = ContentType.json;
      }

      if (yValue is! int) {
        return Response.badRequest(
          body: {'error': 'Поле y должно быть числом, получено: ${yValue.runtimeType}'}
        )..contentType = ContentType.json;
      }

      if (isHitValue is! bool) {
        return Response.badRequest(
          body: {'error': 'Поле isHit должно быть логическим значением, получено: ${isHitValue.runtimeType}'}
        )..contentType = ContentType.json;
      }

      if (userUniqueIdValue is! String || userUniqueIdValue.isEmpty) {
        return Response.badRequest(
          body: {'error': 'Поле userUniqueId должно быть непустой строкой'}
        )..contentType = ContentType.json;
      }

      // После проверки типов используем переменные с правильными типами
      final x = xValue;
      final y = yValue;
      final isHit = isHitValue;
      final userUniqueId = userUniqueIdValue;

      // Валидация координат
      final validationError = validateShotCoordinates(x, y);
      if (validationError != null) {
        return Response.badRequest(
          body: {'error': validationError}
        )..contentType = ContentType.json;
      }

      GameWSController.broadcastSendShot(
        id,
        userUniqueId,
        x,
        y,
        isHit: isHit
      );

      return Response.ok({'message': 'Выстрел отправлен сопернику'})..contentType = ContentType.json;
    } catch (e) {
      return Response.serverError(body: {'error': e.toString()});
    }
  }
}
