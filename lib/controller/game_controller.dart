import 'dart:async';
import 'dart:io';
import 'package:conduit_core/conduit_core.dart';
import 'package:seabattle_app/model/game.dart';

/// Контроллер для управления играми.
///
/// Предоставляет API для создания новых игр и получения списка всех игр.
/// Поддерживает как JSON API, так и HTML представление списка игр.
class GameController extends ResourceController {
  /// Создает новый экземпляр контроллера игр.
  ///
  /// [context] - контекст базы данных для выполнения операций с играми.
  GameController(this.context);

  /// Контекст базы данных для выполнения операций с играми.
  final ManagedContext context;

  /// Создает новую игру в базе данных.
  ///
  /// Принимает данные игры в теле запроса и сохраняет их в базе данных.
  /// Возвращает созданную игру с присвоенным ID и временем создания.
  ///
  /// [game] - объект игры с данными для создания.
  /// Возвращает [Response] с данными созданной игры в формате JSON или ошибку сервера.
  @Operation.post()
  Future<Response> createGame(@Bind.body() Game game) async {
    try {
      final query = Query<Game>(context)
        ..values = game;

      final insertedGame = await query.insert();

      // Возвращаем только ID созданной записи
      return Response.ok({
        'id': insertedGame.id,
        'name': insertedGame.name,
        'createdAt': insertedGame.createdAt?.toIso8601String()
      })
        ..contentType = ContentType.json;
    } catch (e) {
      return Response.serverError(body: {'error': e.toString()});
    }
  }

  /// Получает список всех игр из базы данных.
  ///
  /// Возвращает HTML страницу со списком всех игр, отсортированных
  /// по дате создания в порядке убывания (новые игры первыми).
  ///
  /// Возвращает [Response] с HTML страницей или ошибку сервера.
  @Operation.get()
  Future<Response> getAllGames() async {
    try {
      final query = Query<Game>(context)
        ..sortBy((m) => m.createdAt, QuerySortOrder.descending);

      final games = await query.fetch();

      // Создаем HTML страницу
      final html = _generateHtmlPage(games);

      return Response.ok(html)
        ..contentType = ContentType.html;
    } catch (e) {
      return Response.serverError(body: {'error': e.toString()});
    }
  }

  /// Генерирует HTML страницу со списком игр.
  ///
  /// Создает HTML разметку с таблицей, содержащей информацию о всех играх.
  /// Если список игр пуст, отображается соответствующее сообщение.
  ///
  /// [games] - список игр для отображения.
  /// Возвращает HTML строку с полной страницей.
  String _generateHtmlPage(List<Game> games) {
    final gamesHtml = games.map((game) => '''
      <tr>
        <td>${game.id}</td>
        <td>${game.name ?? '??'}</td>
        <td>${game.createdAt?.toLocal().toString() ?? '??'}</td>
      </tr>
    ''').join('');

    return '''
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Игры</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .empty {
            text-align: center;
            color: #666;
            font-style: italic;
            padding: 40px;
        }
        .refresh-btn {
            background-color: #007bff;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            margin-bottom: 20px;
        }
        .refresh-btn:hover {
            background-color: #0056b3;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Список игр</h1>
        <button class="refresh-btn" onclick="location.reload()">Обновить</button>

        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Название</th>
                    <th>Дата создания</th>
                </tr>
            </thead>
            <tbody>
                ${games.isEmpty ? '<tr><td colspan="3" class="empty">Нет записей</td></tr>' : gamesHtml}
            </tbody>
        </table>
    </div>
</body>
</html>
    ''';
  }
}
