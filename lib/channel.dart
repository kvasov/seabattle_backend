import 'package:seabattle_app/controller/game_controller.dart';
import 'package:seabattle_app/controller/game_update_controller.dart';
import 'package:seabattle_app/controller/game_websocket_controller.dart';
import 'package:seabattle_app/controller/send_ships_controller.dart';
import 'package:seabattle_app/controller/send_shot_controller.dart';
import 'package:seabattle_app/model/game.dart';
import 'package:seabattle_app/seabattle_app.dart';

  /// Основной канал приложения "Морской бой".
  ///
  /// Инициализирует приложение, настраивает маршруты и инициализирует
  /// сервисы, такие как подключение к базе данных.
  /// См. http://conduit.io/docs/http/channel/.
class SeabattleChannel extends ApplicationChannel {
  /// Контекст базы данных для выполнения операций с моделями.
  late ManagedContext context;

  /// Инициализирует сервисы приложения.
  ///
  /// Выполняет инициализацию сервисов, читает значения из [options]
  /// и выполняет другую инициализацию, необходимую перед созданием [entryPoint].
  ///
  /// Этот метод вызывается до обращения к [entryPoint].
  ///
  /// Настраивает логирование, загружает конфигурацию и создает подключение к базе данных.
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

  /// Создает точку входа для обработки запросов.
  ///
  /// Возвращает экземпляр [Controller], который будет начальным получателем
  /// всех [Request].
  ///
  /// Этот метод вызывается после [prepare].
  ///
  /// Настраивает маршруты для WebSocket соединений, API эндпоинтов
  /// и статических файлов.
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
        .route("/api/game/send-ships-to-opponent/:id")
        .link(() => SendShipsToOpponentController(context));

    router
        .route("/api/game/send-shot-to-opponent/:id")
        .link(() => SendShotToOpponentController(context));


    // API роут для создания игры
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

  /// Создает контекст базы данных с указанными параметрами подключения.
  ///
  /// Вспомогательный метод для создания контекста базы данных с
  /// пользовательскими параметрами подключения.
  ///
  /// [connectionInfo] - конфигурация подключения к базе данных.
  /// Возвращает [ManagedContext] с настроенным подключением.
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

/// Конфигурация приложения "Морской бой".
///
/// Экземпляр этого класса читает значения из файла конфигурации,
/// специфичного для данного приложения.
///
/// Файлы конфигурации должны содержать пары ключ-значение для свойств
/// этого класса. Для дополнительной документации по файлам конфигурации
/// см. https://conduit.io/docs/configure/ и
/// https://pub.dartlang.org/packages/safe_config.
class SeabattleConfiguration extends Configuration {
  /// Создает конфигурацию из указанного файла.
  ///
  /// [fileName] - путь к файлу конфигурации.
  SeabattleConfiguration(String fileName) : super.fromFile(File(fileName));

  /// Конфигурация подключения к базе данных.
  DatabaseConfiguration? database;
}
