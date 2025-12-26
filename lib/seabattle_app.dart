/// Библиотека приложения "Морской бой".
///
/// Веб-сервер на базе Conduit для игры "Морской бой" с поддержкой
/// WebSocket соединений для обновлений в реальном времени.
library seabattle;

export 'dart:async';
export 'dart:io';

export 'package:conduit_core/conduit_core.dart';
export 'package:conduit_postgresql/conduit_postgresql.dart';

export 'channel.dart';
