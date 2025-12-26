import 'package:seabattle_app/seabattle_app.dart';

/// Модель данных для игры в "Морской бой".
///
/// Представляет игру в базе данных с информацией о её статусе,
/// названии и времени создания.
class Game extends ManagedObject<_Game> implements _Game {
  /// Вызывается перед вставкой новой записи в базу данных.
  ///
  /// Устанавливает время создания игры в UTC и инициализирует
  /// поля cancelled и accepted значениями по умолчанию (false).
  @override
  void willInsert() {
    createdAt = DateTime.now().toUtc();
    cancelled ??= false;
    accepted ??= false;
  }
}

/// Внутренняя таблица базы данных для хранения игр.
class _Game {
  /// Уникальный идентификатор игры.
  @primaryKey
  int? id;

  /// Название игры.
  @Column(indexed: true)
  String? name = '';

  /// Флаг отмены игры.
  ///
  /// Если true, игра была отменена одним из игроков.
  @Column(indexed: true)
  bool? cancelled;

  /// Флаг принятия игры.
  ///
  /// Если true, игра была принята вторым игроком.
  @Column(indexed: true)
  bool? accepted;

  /// Дата и время создания игры.
  DateTime? createdAt;
}
