import 'package:flutter_test/flutter_test.dart';
import 'package:oyun_blok_kule_dengesi/oyun_blok_kule_dengesi.dart';
import 'package:studio_core/core/level_plan.dart';

void main() {
  final rules = TowerRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('denge kuralı', () {
    expect(stableMask(7), isTrue);
    expect(stableMask(5), isTrue);
    expect(stableMask(2), isTrue);
    expect(stableMask(1), isFalse);
    expect(stableMask(4), isFalse);
    expect(stableMask(0), isFalse);
  });

  test('özet durum gerçek oyunla aynı sonucu verir', () {
    // Küçük kulelerde tam arama ile özet sonucu karşılaştır.
    bool brute(TowerGame g) {
      final ms = g.safeMoves();
      if (ms.isEmpty) return false;
      for (final m in ms) {
        final c = g.clone();
        c.move(m.$1, m.$2);
        if (c.over || !brute(c)) return true;
      }
      return false;
    }

    for (final layers in [
      [7, 7, 7],
      [7, 7, 7, 7],
      [6, 7, 7, 7],
      [5, 7, 3, 7, 7],
      [7, 2, 7, 7, 1],
    ]) {
      final g = TowerGame(TowerLevel(layers: layers, seed: 1, difficulty: 5));
      expect(winning(g.state), brute(g), reason: '$layers');
    }
  });

  test('bölümler kazanılabilir; oyuncu en iyi oynayınca kazanır', () {
    for (final lv in [1, 12, 50, 99, 230, 777, 2500, 9999, 33333, 49999]) {
      final gl = rules.build(planner.spec(lv));
      expect(gl.validation.ok, isTrue, reason: 'bölüm $lv');
      expect(gl.attempts, lessThan(40));
    }
  });

  test('kayıt geri yüklenir', () {
    final l = rules.build(planner.spec(9)).puzzle;
    final g = TowerGame(l);
    final m = g.winningMove()!;
    g.move(m.$1, m.$2);
    final r = TowerGame.restore(l, g.serialize());
    expect(r.serialize(), g.serialize());
  });
}
