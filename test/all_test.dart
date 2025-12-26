import 'dart:convert';

import 'package:seabattle_app/controller/game_websocket_controller.dart';

import 'harness/app.dart';

Future main() async {
  final harness = Harness()..install();

  tearDown(() async {
    await harness.resetData();
  });

  test("POST /api/game создает новую игру", () async {
    final response = await harness.agent!.post("/api/game", body: {"name": "Test Game"});
    expect(
        response,
        hasResponse(200,
            body: {
              "id": isNotNull,
              "name": "Test Game",
              "createdAt": isA<String>()
            }));
  });

  test("GET /game/:id возвращает ранее созданную игру", () async {
    var response = await harness.agent!.post("/api/game", body: {"name": "Test Game"});

    final createdObject = response?.body.as();
    final gameId = createdObject["id"];

    response = await harness.agent!.request("/game/$gameId").get();
    expect(
        response,
        hasResponse(200, body: {
          "id": gameId,
          "name": "Test Game",
          "cancelled": false,
          "accepted": false,
          "createdAt": isNotNull
        }));
  });

  test("POST /api/game/send-shot-to-opponent/:id валидирует координаты выстрела", () async {
    // Создаем игру
    var response = await harness.agent!.post("/api/game", body: {"name": "Test Game"});
    final createdObject = response?.body.as();
    final gameId = createdObject["id"];

    // Тест с валидными координатами
    response = await harness.agent!.post(
      "/api/game/send-shot-to-opponent/$gameId",
      body: {
        "x": 5,
        "y": 5,
        "isHit": false,
        "userUniqueId": "user123"
      }
    );
    expect(response, hasResponse(200, body: {"message": "Выстрел отправлен сопернику"}));

    // Тест с невалидными координатами (x вне диапазона)
    response = await harness.agent!.post(
      "/api/game/send-shot-to-opponent/$gameId",
      body: {
        "x": 10,
        "y": 5,
        "isHit": false,
        "userUniqueId": "user123"
      }
    );
    expect(response, hasResponse(400, body: {"error": contains("Координата X должна быть от 0 до 9")}));

    // Тест с невалидными координатами (y вне диапазона)
    response = await harness.agent!.post(
      "/api/game/send-shot-to-opponent/$gameId",
      body: {
        "x": 5,
        "y": -1,
        "isHit": false,
        "userUniqueId": "user123"
      }
    );
    expect(response, hasResponse(400, body: {"error": contains("Координата Y должна быть от 0 до 9")}));
  });

  test("POST /api/game/send-ships-to-opponent/:id валидирует расстановку кораблей", () async {
    // Создаем игру
    var response = await harness.agent!.post("/api/game", body: {"name": "Test Game"});
    final createdObject = response?.body.as();
    final gameId = createdObject["id"];

    // Валидная расстановка кораблей
    final validShips = [
      {"x": 0, "y": 0, "size": 4, "isHorizontal": true},  // 1 корабль на 4 клетки
      {"x": 0, "y": 2, "size": 3, "isHorizontal": true},  // 2 корабля на 3 клетки
      {"x": 0, "y": 4, "size": 3, "isHorizontal": true},
      {"x": 0, "y": 6, "size": 2, "isHorizontal": true},   // 3 корабля на 2 клетки
      {"x": 0, "y": 8, "size": 2, "isHorizontal": true},
      {"x": 3, "y": 6, "size": 2, "isHorizontal": true},
      {"x": 5, "y": 0, "size": 1, "isHorizontal": true},   // 4 корабля на 1 клетку
      {"x": 5, "y": 2, "size": 1, "isHorizontal": true},
      {"x": 5, "y": 4, "size": 1, "isHorizontal": true},
      {"x": 5, "y": 6, "size": 1, "isHorizontal": true},
    ];

    response = await harness.agent!.post(
      "/api/game/send-ships-to-opponent/$gameId",
      body: {
        "ships": validShips,
        "userUniqueId": "user123"
      }
    );
    expect(response, hasResponse(200, body: {"message": "Корабли отправлены сопернику"}));

    // Невалидная расстановка (неправильное количество кораблей)
    final invalidShips = [
      {"x": 0, "y": 0, "size": 4, "isHorizontal": true},
      {"x": 0, "y": 2, "size": 3, "isHorizontal": true},
    ];

    response = await harness.agent!.post(
      "/api/game/send-ships-to-opponent/$gameId",
      body: {
        "ships": invalidShips,
        "userUniqueId": "user123"
      }
    );
    expect(response, hasResponse(400, body: {"error": contains("Неверное количество кораблей")}));
  });

  group("WebSocket тесты", () {
    test("WebSocket соединение устанавливается успешно", () async {
      // Получаем порт сервера из харнеса
      final baseUrl = Uri.parse(harness.agent!.baseURL);
      final wsUrl = Uri(
        scheme: 'ws',
        host: baseUrl.host,
        port: baseUrl.port,
        path: '/ws',
      );

      // Устанавливаем WebSocket соединение
      final socket = await WebSocket.connect(wsUrl.toString());

      expect(socket.readyState, WebSocket.open);

      // Закрываем соединение
      await socket.close();
    });

    test("WebSocket устанавливает фильтр gameId при получении сообщения", () async {
      // Создаем игру
      final response = await harness.agent!.post("/api/game", body: {"name": "Test Game"});
      final createdObject = response?.body.as();
      final gameId = createdObject["id"];

      // Устанавливаем WebSocket соединение
      final baseUrl = Uri.parse(harness.agent!.baseURL);
      final wsUrl = Uri(
        scheme: 'ws',
        host: baseUrl.host,
        port: baseUrl.port,
        path: '/ws',
      );

      final socket = await WebSocket.connect(wsUrl.toString());

      // Отправляем сообщение с gameId для установки фильтра
      socket.add(jsonEncode({"gameId": gameId}));

      // Даем время на обработку сообщения
      await Future.delayed(Duration(milliseconds: 200));

      // Проверяем, что соединение активно
      expect(socket.readyState, WebSocket.open);

      await socket.close();
    });

    test("broadcastUpdateGame отправляет сообщение только клиентам с соответствующим gameId", () async {
      // Создаем игру
      var response = await harness.agent!.post("/api/game", body: {"name": "Test Game"});
      final createdObject = response?.body.as();
      final gameId = createdObject["id"];

      // Создаем другую игру
      response = await harness.agent!.post("/api/game", body: {"name": "Test Game 2"});
      final createdObject2 = response?.body.as();
      final gameId2 = createdObject2["id"];

      // Устанавливаем два WebSocket соединения
      final baseUrl = Uri.parse(harness.agent!.baseURL);
      final wsUrl = Uri(
        scheme: 'ws',
        host: baseUrl.host,
        port: baseUrl.port,
        path: '/ws',
      );

      final socket1 = await WebSocket.connect(wsUrl.toString());
      final socket2 = await WebSocket.connect(wsUrl.toString());

      // Устанавливаем фильтры для каждого соединения
      socket1.add(jsonEncode({"gameId": gameId}));
      socket2.add(jsonEncode({"gameId": gameId2}));

      // Даем время на обработку сообщений
      await Future.delayed(Duration(milliseconds: 200));

      // Собираем сообщения от обоих сокетов
      final messages1 = <String>[];
      final messages2 = <String>[];

      socket1.listen((message) {
        messages1.add(message);
      });

      socket2.listen((message) {
        messages2.add(message);
      });

      // Вызываем broadcastUpdateGame напрямую через статический метод
      GameWSController.broadcastUpdateGame(gameId, 'accepted', 'user123');

      // Даем время на отправку сообщений
      await Future.delayed(Duration(milliseconds: 200));

      // Проверяем, что сообщение получил только первый клиент
      expect(messages1.length, greaterThan(0));
      expect(messages2.length, 0);

      // Проверяем содержимое сообщения
      final receivedData = jsonDecode(messages1.first) as Map<String, dynamic>;
      expect(receivedData["id"], gameId);
      expect(receivedData["mode"], "accepted");

      await socket1.close();
      await socket2.close();
    });

    test("broadcastSendShips отправляет данные о кораблях клиентам", () async {
      // Создаем игру
      var response = await harness.agent!.post("/api/game", body: {"name": "Test Game"});
      final createdObject = response?.body.as();
      final gameId = createdObject["id"];

      // Устанавливаем WebSocket соединение
      final baseUrl = Uri.parse(harness.agent!.baseURL);
      final wsUrl = Uri(
        scheme: 'ws',
        host: baseUrl.host,
        port: baseUrl.port,
        path: '/ws',
      );

      final socket = await WebSocket.connect(wsUrl.toString());

      // Устанавливаем фильтр
      socket.add(jsonEncode({"gameId": gameId}));
      await Future.delayed(Duration(milliseconds: 200));

      // Собираем сообщения
      final messages = <String>[];
      socket.listen((message) {
        messages.add(message);
      });

      // Отправляем корабли через API
      final ships = [
        {"x": 0, "y": 0, "size": 4, "isHorizontal": true},
        {"x": 0, "y": 2, "size": 3, "isHorizontal": true},
        {"x": 0, "y": 4, "size": 3, "isHorizontal": true},
        {"x": 0, "y": 6, "size": 2, "isHorizontal": true},
        {"x": 0, "y": 8, "size": 2, "isHorizontal": true},
        {"x": 3, "y": 6, "size": 2, "isHorizontal": true},
        {"x": 5, "y": 0, "size": 1, "isHorizontal": true},
        {"x": 5, "y": 2, "size": 1, "isHorizontal": true},
        {"x": 5, "y": 4, "size": 1, "isHorizontal": true},
        {"x": 5, "y": 6, "size": 1, "isHorizontal": true},
      ];

      response = await harness.agent!.post(
        "/api/game/send-ships-to-opponent/$gameId",
        body: {
          "ships": ships,
          "userUniqueId": "user123"
        }
      );

      // Даем время на отправку сообщения через WebSocket
      await Future.delayed(Duration(milliseconds: 300));

      // Проверяем, что сообщение было получено
      expect(messages.length, greaterThan(0));

      // Проверяем содержимое сообщения
      final receivedData = jsonDecode(messages.first) as Map<String, dynamic>;
      expect(receivedData["id"], gameId);
      expect(receivedData["userUniqueId"], "user123");
      expect(receivedData["ships"], isA<List>());

      await socket.close();
    });

    test("broadcastSendShot отправляет данные о выстреле клиентам", () async {
      // Создаем игру
      var response = await harness.agent!.post("/api/game", body: {"name": "Test Game"});
      final createdObject = response?.body.as();
      final gameId = createdObject["id"];

      // Устанавливаем WebSocket соединение
      final baseUrl = Uri.parse(harness.agent!.baseURL);
      final wsUrl = Uri(
        scheme: 'ws',
        host: baseUrl.host,
        port: baseUrl.port,
        path: '/ws',
      );

      final socket = await WebSocket.connect(wsUrl.toString());

      // Устанавливаем фильтр
      socket.add(jsonEncode({"gameId": gameId}));
      await Future.delayed(Duration(milliseconds: 200));

      // Собираем сообщения
      final messages = <String>[];
      socket.listen((message) {
        messages.add(message);
      });

      // Отправляем выстрел через API
      response = await harness.agent!.post(
        "/api/game/send-shot-to-opponent/$gameId",
        body: {
          "x": 5,
          "y": 5,
          "isHit": true,
          "userUniqueId": "user123"
        }
      );

      // Даем время на отправку сообщения через WebSocket
      await Future.delayed(Duration(milliseconds: 300));

      // Проверяем, что сообщение было получено
      expect(messages.length, greaterThan(0));

      // Проверяем содержимое сообщения
      final receivedData = jsonDecode(messages.first) as Map<String, dynamic>;
      expect(receivedData["type"], "shot");
      expect(receivedData["id"], gameId);
      expect(receivedData["userUniqueId"], "user123");
      expect(receivedData["x"], 5);
      expect(receivedData["y"], 5);
      expect(receivedData["isHit"], true);

      await socket.close();
    });

    test("WebSocket соединение фильтрует сообщения по gameId", () async {
      // Создаем две игры
      var response = await harness.agent!.post("/api/game", body: {"name": "Game 1"});
      final game1 = response?.body.as();
      final gameId1 = game1["id"];

      response = await harness.agent!.post("/api/game", body: {"name": "Game 2"});
      final game2 = response?.body.as();
      final gameId2 = game2["id"];

      // Устанавливаем два WebSocket соединения с разными фильтрами
      final baseUrl = Uri.parse(harness.agent!.baseURL);
      final wsUrl = Uri(
        scheme: 'ws',
        host: baseUrl.host,
        port: baseUrl.port,
        path: '/ws',
      );

      final socket1 = await WebSocket.connect(wsUrl.toString());
      final socket2 = await WebSocket.connect(wsUrl.toString());

      // Устанавливаем фильтры
      socket1.add(jsonEncode({"gameId": gameId1}));
      socket2.add(jsonEncode({"gameId": gameId2}));
      await Future.delayed(Duration(milliseconds: 200));

      // Собираем сообщения
      final messages1 = <String>[];
      final messages2 = <String>[];

      socket1.listen((message) {
        messages1.add(message);
      });

      socket2.listen((message) {
        messages2.add(message);
      });

      // Отправляем выстрел для первой игры
      response = await harness.agent!.post(
        "/api/game/send-shot-to-opponent/$gameId1",
        body: {
          "x": 3,
          "y": 3,
          "isHit": false,
          "userUniqueId": "user1"
        }
      );

      await Future.delayed(Duration(milliseconds: 300));

      // Проверяем, что сообщение получил только первый клиент
      expect(messages1.length, greaterThan(0));
      expect(messages2.length, 0);

      // Проверяем содержимое сообщения первого клиента
      final receivedData = jsonDecode(messages1.first) as Map<String, dynamic>;
      expect(receivedData["id"], gameId1);

      await socket1.close();
      await socket2.close();
    });
  });
}
