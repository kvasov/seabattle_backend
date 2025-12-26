import 'package:conduit_test/conduit_test.dart';
import 'package:seabattle_app/seabattle_app.dart';

export 'package:conduit_core/conduit_core.dart';
export 'package:conduit_test/conduit_test.dart';
export 'package:seabattle_app/seabattle_app.dart';
export 'package:test/test.dart';

/// тестовый харнес. Настраиваем окружение для тестов и управляем жизненным циклом.
///
/// пример тестового файла:
///
///         void main() {
///           Harness harness = Harness()..install();
///
///           test("GET /path returns 200", () async {
///             final response = await harness.agent.get("/path");
///             expectResponse(response, 200);
///           });
///         }
///
class Harness extends TestHarness<SeabattleChannel> with TestHarnessORMMixin {
  @override
  ManagedContext? get context => channel?.context;

  @override
  Future onSetUp() async {
    await resetData();
  }

  @override
  Future onTearDown() async {}

  @override
  Future seed() async {
  }
}
