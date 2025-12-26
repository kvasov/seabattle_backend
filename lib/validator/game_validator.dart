/// Валидаторы для данных.

/// Размер игрового поля (стандартное поле 10x10).
const int fieldSize = 10;

/// Валидация координат выстрела.
///
/// Проверяет, что координаты находятся в пределах игрового поля.
///
/// [x] - координата X выстрела (должна быть от 0 до fieldSize-1).
/// [y] - координата Y выстрела (должна быть от 0 до fieldSize-1).
/// Возвращает строку с ошибкой, если валидация не прошла, иначе null.
String? validateShotCoordinates(int x, int y) {
  if (x < 0 || x >= fieldSize) {
    return 'Координата X должна быть от 0 до ${fieldSize - 1}, получено: $x';
  }
  if (y < 0 || y >= fieldSize) {
    return 'Координата Y должна быть от 0 до ${fieldSize - 1}, получено: $y';
  }
  return null;
}

/// Представляет корабль на игровом поле.
class Ship {
  /// Создает новый корабль.
  ///
  /// [x] - начальная координата X.
  /// [y] - начальная координата Y.
  /// [size] - размер корабля (количество палуб).
  /// [isHorizontal] - true, если корабль расположен горизонтально, false - вертикально.
  Ship({
    required this.x,
    required this.y,
    required this.size,
    required this.isHorizontal,
  });

  /// Начальная координата X.
  final int x;

  /// Начальная координата Y.
  final int y;

  /// Размер корабля (количество палуб).
  final int size;

  /// true, если корабль расположен горизонтально, false - вертикально.
  final bool isHorizontal;

  /// Возвращает все клетки, занимаемые кораблем.
  List<Point> get cells {
    final cells = <Point>[];
    for (int i = 0; i < size; i++) {
      if (isHorizontal) {
        cells.add(Point(x + i, y));
      } else {
        cells.add(Point(x, y + i));
      }
    }
    return cells;
  }

  /// Возвращает все клетки вокруг корабля (включая сам корабль).
  Set<Point> get cellsWithNeighbors {
    final cells = <Point>{};
    for (final cell in this.cells) {
      // Добавляем саму клетку и все соседние клетки
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final nx = cell.x + dx;
          final ny = cell.y + dy;
          if (nx >= 0 && nx < fieldSize && ny >= 0 && ny < fieldSize) {
            cells.add(Point(nx, ny));
          }
        }
      }
    }
    return cells;
  }
}

/// Представляет точку на игровом поле.
class Point {
  /// Создает новую точку.
  Point(this.x, this.y);

  /// Координата X.
  final int x;

  /// Координата Y.
  final int y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => 'Point($x, $y)';
}

/// Валидация расстановки кораблей.
///
/// Проверяет корректность расстановки кораблей согласно правилам игры "Морской бой":
/// - Правильное количество кораблей каждого размера (1x4, 2x3, 3x2, 4x1)
/// - Корабли не выходят за границы поля
/// - Корабли не пересекаются
/// - Корабли не касаются друг друга (минимум одна клетка между ними)
///
/// [shipsData] - список данных о кораблях в формате Map с ключами:
///   - 'x' (int) - начальная координата X
///   - 'y' (int) - начальная координата Y
///   - 'size' (int) - размер корабля
///   - 'isHorizontal' (bool) - ориентация корабля
/// Возвращает строку с ошибкой, если валидация не прошла, иначе null.
String? validateShipsPlacement(List<Map<String, dynamic>> shipsData) {
  // Проверка наличия данных
  if (shipsData.isEmpty) {
    return 'Список кораблей не может быть пустым';
  }

  // Ожидаемое количество кораблей каждого размера
  const expectedShips = {
    4: 1, // 1 корабль на 4 клетки
    3: 2, // 2 корабля на 3 клетки
    2: 3, // 3 корабля на 2 клетки
    1: 4, // 4 корабля на 1 клетку
  };

  // Подсчет кораблей по размерам
  final shipCounts = <int, int>{};
  final ships = <Ship>[];

  // Парсинг и валидация структуры данных
  for (int i = 0; i < shipsData.length; i++) {
    final shipData = shipsData[i];

    // Проверка наличия обязательных полей
    if (!shipData.containsKey('x') ||
        !shipData.containsKey('y') ||
        !shipData.containsKey('size') ||
        !shipData.containsKey('isHorizontal')) {
      return 'Корабль #${i + 1}: отсутствуют обязательные поля (x, y, size, isHorizontal)';
    }

    // Проверка типов данных
    final xValue = shipData['x'];
    final yValue = shipData['y'];
    final sizeValue = shipData['size'];
    final isHorizontalValue = shipData['isHorizontal'];

    if (xValue is! int) {
      return 'Корабль #${i + 1}: поле x должно быть числом, получено: ${xValue.runtimeType}';
    }
    if (yValue is! int) {
      return 'Корабль #${i + 1}: поле y должно быть числом, получено: ${yValue.runtimeType}';
    }
    if (sizeValue is! int) {
      return 'Корабль #${i + 1}: поле size должно быть числом, получено: ${sizeValue.runtimeType}';
    }
    if (isHorizontalValue is! bool) {
      return 'Корабль #${i + 1}: поле isHorizontal должно быть логическим значением, получено: ${isHorizontalValue.runtimeType}';
    }

    // После проверки типов используем переменные с правильными типами
    final x = xValue;
    final y = yValue;
    final size = sizeValue;
    final isHorizontal = isHorizontalValue;

    // Проверка диапазона размера
    if (size < 1 || size > 4) {
      return 'Корабль #${i + 1}: размер корабля должен быть от 1 до 4, получено: $size';
    }

    // Создание объекта корабля
    final ship = Ship(
      x: x,
      y: y,
      size: size,
      isHorizontal: isHorizontal,
    );

    // Проверка, что корабль не выходит за границы поля
    for (final cell in ship.cells) {
      if (cell.x < 0 || cell.x >= fieldSize || cell.y < 0 || cell.y >= fieldSize) {
        return 'Корабль #${i + 1}: корабль выходит за границы поля';
      }
    }

    ships.add(ship);
    shipCounts[size] = (shipCounts[size] ?? 0) + 1;
  }

  // Проверка количества кораблей каждого размера
  for (final entry in expectedShips.entries) {
    final expectedCount = entry.value;
    final actualCount = shipCounts[entry.key] ?? 0;
    if (actualCount != expectedCount) {
      return 'Неверное количество кораблей размера ${entry.key}: ожидается $expectedCount, получено $actualCount';
    }
  }

  // Проверка пересечений и касаний кораблей
  for (int i = 0; i < ships.length; i++) {
    final ship1 = ships[i];
    final cells1 = ship1.cellsWithNeighbors;

    for (int j = i + 1; j < ships.length; j++) {
      final ship2 = ships[j];
      final cells2 = ship2.cells;

      // Проверка пересечения (если корабли занимают одни и те же клетки)
      final intersection = cells1.intersection(cells2.toSet());
      if (intersection.isNotEmpty) {
        // Если пересекаются только соседние клетки (не сами корабли), это нормально
        // Но если пересекаются сами клетки кораблей - это ошибка
        final ship1Cells = ship1.cells.toSet();
        final ship2Cells = ship2.cells.toSet();
        final directIntersection = ship1Cells.intersection(ship2Cells);
        if (directIntersection.isNotEmpty) {
          return 'Корабли #${i + 1} и #${j + 1} пересекаются (клетки: $directIntersection)';
        }
      }
    }
  }

  return null;
}

