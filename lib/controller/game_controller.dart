import 'dart:async';
import 'dart:io';
import 'package:conduit_core/conduit_core.dart';
import 'package:seabattle_app/model/game.dart';

class GameController extends ResourceController {
  GameController(this.context);

  final ManagedContext context;

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
