import 'dart:io';
import 'package:conduit_core/conduit_core.dart';
import 'package:seabattle_app/controller/game_websocket_controller.dart';

class SendShotToOpponentController extends ResourceController {
  SendShotToOpponentController(this.context);

  final ManagedContext context;

  @Operation.post('id')
  Future<Response> sendShipsToOpponent(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {
    try {
      print("sendShipsToOpponent raw request body: $body");
      print("sendShipsToOpponent controller called with id: $id");
      final x = body['x'] as int;
      final y = body['y'] as int;
      final isHit = body['isHit'] as bool;
      GameWSController.broadcastSendShot(id, body['userUniqueId'], x, y, isHit);

      return Response.ok({'message': 'Выстрел отправлен сопернику'})..contentType = ContentType.json;
    } catch (e) {
      return Response.serverError(body: {'error': e.toString()});
    }
  }
}
