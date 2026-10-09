import 'package:flutter_test/flutter_test.dart';
import 'package:kids_learning_app/core/progress/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Progress.instance.clearForTest();
  });

  test('progress is saved and comes back after a restart', () async {
    final p = Progress.instance;
    p
      ..addStar()
      ..addStar()
      ..markTraced('upper', 'a')
      ..markTraced('lower', 'a')
      ..markTraced('number', '3')
      ..markSeen('letters', 'b')
      ..gameFinished();
    await Future<void>.delayed(Duration.zero); // let the save finish

    p.clearForTest(); // like closing the app
    expect(p.stars, 0);
    await p.load();

    expect(p.stars, 2);
    expect(p.starCount.value, 2);
    expect(p.isTraced('upper', 'a'), isTrue);
    expect(p.isTraced('lower', 'a'), isTrue);
    expect(p.isTraced('number', '3'), isTrue);
    expect(p.isTraced('upper', 'b'), isFalse);
    expect(p.seen('letters'), {'b'});
    expect(p.gamesFinished, 1);
  });

  test('reset clears everything, also on the device', () async {
    final p = Progress.instance
      ..addStar(5)
      ..markTraced('upper', 'z');
    await p.reset();
    await Future<void>.delayed(Duration.zero);
    p.clearForTest();
    await p.load();
    expect(p.stars, 0);
    expect(p.traced('upper'), isEmpty);
  });

  test('damaged saved data starts fresh instead of crashing', () async {
    SharedPreferences.setMockInitialValues({'progress_v1': '{not json'});
    await Progress.instance.load();
    expect(Progress.instance.stars, 0);
  });
}
