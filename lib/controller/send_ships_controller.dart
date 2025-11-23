import 'dart:io';
import 'package:conduit_core/conduit_core.dart';
import 'package:seabattle_app/controller/game_websocket_controller.dart';

class SendShipsToOpponentController extends ResourceController {
  SendShipsToOpponentController(this.context);

  final ManagedContext context;

  @Operation.post('id')
  Future<Response> sendShipsToOpponent(@Bind.path('id') int id, @Bind.body() Map<String, dynamic> body) async {
    try {
      print("sendShipsToOpponent raw request body: $body");
      print("sendShipsToOpponent controller called with id: $id");
      final ships = (body['ships'] as List).cast<Map<String, dynamic>>();
      GameWSController.broadcastSendShips(id, body['userUniqueId'], ships);

      return Response.ok({'message': 'Корабли отправлены сопернику'})..contentType = ContentType.json;
    } catch (e) {
      return Response.serverError(body: {'error': e.toString()});
    }
  }
}
