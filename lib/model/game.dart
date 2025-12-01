import 'package:seabattle_app/seabattle_app.dart';

class Game extends ManagedObject<_Game> implements _Game {
  @override
  void willInsert() {
    createdAt = DateTime.now().toUtc();
    cancelled ??= false;
    accepted ??= false;
  }
}

class _Game {
  @primaryKey
  int? id;

  @Column(indexed: true)
  String? name = '';

  @Column(indexed: true)
  bool? cancelled;

  @Column(indexed: true)
  bool? accepted;

  DateTime? createdAt;
}
