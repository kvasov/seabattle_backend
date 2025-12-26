import 'package:seabattle_app/seabattle_app.dart';

/// Точка входа в приложение "Морской бой".
///
/// Инициализирует и запускает сервер приложения на порту 8888.
/// Конфигурация загружается из файла config.yaml.
Future main() async {
  final app = Application<SeabattleChannel>()
    ..options.configurationFilePath = "config.yaml"
    ..options.port = 8888;

  await app.startOnCurrentIsolate();

  print("Application started on port: ${app.options.port}.");
  print("Use Ctrl-C (SIGINT) to stop running the application.");
}
