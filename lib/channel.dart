import 'package:seabattle_app/controller/game_controller.dart';
import 'package:seabattle_app/controller/game_update_controller.dart';
import 'package:seabattle_app/controller/game_websocket_controller.dart';
import 'package:seabattle_app/controller/send_ships_controller.dart';
import 'package:seabattle_app/controller/send_shot_controller.dart';
import 'package:seabattle_app/model/game.dart';
import 'package:seabattle_app/seabattle_app.dart';

/// This type initializes an application.
///
/// Override methods in this class to set up routes and initialize services like
/// database connections. See http://conduit.io/docs/http/channel/.
class SeabattleChannel extends ApplicationChannel {
  late ManagedContext context;

  /// Initialize services in this method.
  ///
  /// Implement this method to initialize services, read values from [options]
  /// and any other initialization required before constructing [entryPoint].
  ///
  /// This method is invoked prior to [entryPoint] being accessed.
  @override
  Future prepare() async {
    logger.onRecord.listen(
        (rec) => print("$rec ${rec.error ?? ""} ${rec.stackTrace ?? ""}"));

    final config = SeabattleConfiguration(options!.configurationFilePath!);

    final dataModel = ManagedDataModel.fromCurrentMirrorSystem();
    final psc = PostgreSQLPersistentStore(
        config.database?.username ?? '',
        config.database?.password ?? '',
        config.database?.host ?? 'localhost',
        config.database?.port ?? 5432,
        config.database?.databaseName ?? '');

    context = ManagedContext(dataModel, psc);
  }

  /// Construct the request channel.
  ///
  /// Return an instance of some [Controller] that will be the initial receiver
  /// of all [Request]s.
  ///
  /// This method is invoked after [prepare].
  @override
  Controller get entryPoint {
    final router = Router();

    router
        .route("/ws").link(GameWSController.new);

    // API роуты для обновления игры (параметр id в конце пути) - ДО FileController!
    router
        .route("/api/game/cancel/:id")
        .link(() => CancelGameController(context));

    router
        .route("/api/game/accept/:id")
        .link(() => AcceptGameController(context));

    router
        .route("/api/game/complete/:id")
        .link(() => CompleteGameController(context));

    router
        .route("/api/game/send-ships-to-opponent/:id")
        .link(() => SendShipsToOpponentController(context));
    router
        .route("/api/game/send-shot-to-opponent/:id")
        .link(() => SendShotToOpponentController(context));


    // API роут для создания записи
    router
        .route("/api/game")
        .link(() => GameController(context));

    // Статические файлы из папки web - В КОНЦЕ, чтобы не перехватывать API запросы
    router.route("/*").link(() => FileController("web/"));

    // HTML роут для просмотра всех записей
    router
        .route("/games")
        .link(() => GameController(context));

    // HTML роут для просмотра игры по id
    router
        .route("/game/[:id]")
        .link(() => ManagedObjectController<Game>(context));

    return router;
  }

  /*
   * Helper methods
   */

  ManagedContext contextWithConnectionInfo(
      DatabaseConfiguration connectionInfo) {
    final dataModel = ManagedDataModel.fromCurrentMirrorSystem();
    final psc = PostgreSQLPersistentStore(
        connectionInfo.username,
        connectionInfo.password,
        connectionInfo.host,
        connectionInfo.port,
        connectionInfo.databaseName);

    return ManagedContext(dataModel, psc);
  }
}

/// An instance of this class reads values from a configuration
/// file specific to this application.
///
/// Configuration files must have key-value for the properties in this class.
/// For more documentation on configuration files, see https://conduit.io/docs/configure/ and
/// https://pub.dartlang.org/packages/safe_config.
class SeabattleConfiguration extends Configuration {
  SeabattleConfiguration(String fileName) : super.fromFile(File(fileName));

  DatabaseConfiguration? database;
}
