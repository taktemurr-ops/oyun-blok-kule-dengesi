import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';

import 'tower_engine.dart';

const kuleDengesiId = 'oyun-blok-kule-dengesi';

class TowerRules extends GameRules<TowerLevel> {
  @override
  String get gameId => kuleDengesiId;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => const [
        GameStat('towers_won', 'Kazanılan kule', 'Towers won', scale: 5),
        GameStat('blocks_pulled', 'Çekilen blok', 'Blocks pulled', scale: 60),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('won', 'towers_won', [2, 5, 10]),
        MissionTemplate('pulled', 'blocks_pulled', [20, 60, 150]),
      ];

  @override
  TowerLevel generate(LevelSpec spec) => generateTowerLevel(spec);

  /// Oyuncu ilk oynar; konum mükemmel oyunla oyuncunun kazanacağı türden olmalı.
  @override
  Validation validate(TowerLevel level, LevelSpec spec) {
    final g = TowerGame(level);
    if (g.safeMoves().isEmpty) return const Validation.fail('no move');
    if (!winning(g.state)) return const Validation.fail('not winnable');
    // Oyunu sonuna dek oyna: oyuncu en iyi, bilgisayar kendi düzeyinde.
    var guard = 0;
    while (!g.over && guard++ < 400) {
      final m = g.turn == 0 ? g.winningMove()! : g.computerMove()!;
      g.move(m.$1, m.$2);
    }
    if (g.loser != 1) return const Validation.fail('player did not win');
    return Validation.ok(g.moves);
  }

  static int stars(TowerGame g, int hints) => g.loser != 1 ? 0 : (hints == 0 ? 3 : (hints <= 2 ? 2 : 1));
}
