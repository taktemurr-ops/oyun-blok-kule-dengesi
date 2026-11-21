import 'dart:convert';

import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// Blok Kule Dengesi: sırayla kuleden bir blok çekip tepeye koyarsınız.
/// Her katta üç yuva var (bit 0 sol, bit 1 orta, bit 2 sağ). Bir kat, orta
/// bloğu varsa ya da iki yan bloğu birden varsa taşır. En üst kattan (ve en
/// üst kat yarımsa altındakinden) blok çekilemez. Güvenli hamlesi kalmayan
/// kaybeder: kule onun elinde yıkılır.

bool stableMask(int m) => (m & 2) != 0 || (m & 5) == 5;
int popcount3(int m) => (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1);

class TowerLevel {
  final List<int> layers; // alttan üste
  final int seed, difficulty;
  const TowerLevel({required this.layers, required this.seed, required this.difficulty});
}

/// Konumun özeti: (dolu çekilebilir kat, tek hamlesi kalan kat, tepe doluluğu).
typedef TState = (int, int, int);

final Map<TState, bool> _memo = {};

List<TState> _next(TState s) {
  final (a, b, f) = s;
  final out = <TState>[];
  void place(int na, int nb) {
    if (f == 3) {
      out.add((na, nb, 1));
    } else if (f == 1) {
      out.add((na, nb, 2));
    } else {
      out.add((na + 1, nb, 3));
    }
  }

  if (a > 0) {
    place(a - 1, b + 1); // yandan çek
    place(a - 1, b); // ortadan çek
  }
  if (b > 0) place(a, b - 1);
  return out;
}

/// Sırası gelen oyuncu (mükemmel oyunla) kazanır mı?
bool winning(TState s) {
  final m = _memo[s];
  if (m != null) return m;
  var w = false;
  for (final n in _next(s)) {
    if (!winning(n)) {
      w = true;
      break;
    }
  }
  _memo[s] = w;
  return w;
}

class TowerGame {
  final TowerLevel level;
  late List<int> layers;
  int moves = 0;
  int turn = 0; // 0 oyuncu, 1 bilgisayar
  int? loser; // yıkan taraf
  late SeededRandom _rng;

  TowerGame(this.level) {
    layers = List<int>.of(level.layers);
    _rng = SeededRandom(mixSeed([level.seed, 6060]));
  }

  int get top => layers.length - 1;
  bool get topFull => layers[top] == 7;

  bool removable(int i) => i < top && !(i == top - 1 && !topFull);

  bool safe(int i, int k) => removable(i) && (layers[i] & (1 << k)) != 0 && stableMask(layers[i] & ~(1 << k));

  List<(int, int)> safeMoves() => [
        for (var i = 0; i < top; i++)
          for (var k = 0; k < 3; k++)
            if (safe(i, k)) (i, k)
      ];

  TState get state {
    var a = 0, b = 0;
    for (var i = 0; i < top; i++) {
      if (!removable(i)) continue;
      final m = layers[i];
      if (m == 7) a++;
      if (m == 3 || m == 6) b++;
    }
    return (a, b, popcount3(layers[top]));
  }

  bool get over => loser != null;

  /// Hamle: bloğu çek, tepeye koy, sırayı devret. Sonrasında sıradaki
  /// oyuncunun güvenli hamlesi yoksa o kaybeder.
  bool move(int i, int k) {
    if (over || !safe(i, k)) return false;
    layers[i] &= ~(1 << k);
    if (topFull) {
      layers.add(1);
    } else {
      final t = layers[top];
      layers[top] = (t & 1) == 0 ? t | 1 : ((t & 2) == 0 ? t | 2 : t | 4);
    }
    moves++;
    turn = 1 - turn;
    if (safeMoves().isEmpty) loser = turn;
    return true;
  }

  /// Kazandıran hamle (varsa), yoksa null.
  (int, int)? winningMove() {
    for (final m in safeMoves()) {
      final g = clone();
      g.move(m.$1, m.$2);
      if (g.over || !winning(g.state)) return m;
    }
    return null;
  }

  /// Bilgisayar: zorluğa göre çoğu zaman en iyi hamle, bazen rastgele.
  (int, int)? computerMove() {
    final all = safeMoves();
    if (all.isEmpty) return null;
    final p = 0.45 + level.difficulty * 0.055;
    if (_rng.chance(p)) {
      final w = winningMove();
      if (w != null) return w;
    }
    return all[_rng.nextInt(all.length)];
  }

  TowerGame clone() {
    final g = TowerGame(level);
    g.layers = List<int>.of(layers);
    g.moves = moves;
    g.turn = turn;
    g.loser = loser;
    g._rng = _rng.copy();
    return g;
  }

  String serialize() => jsonEncode({'l': layers, 'm': moves, 't': turn, 'x': loser, 'r': _rng.state});

  static TowerGame restore(TowerLevel l, String snap) {
    final j = jsonDecode(snap) as Map<String, dynamic>;
    final g = TowerGame(l);
    g.layers = [for (final v in j['l'] as List) (v as num).toInt()];
    g.moves = (j['m'] as num).toInt();
    g.turn = (j['t'] as num).toInt();
    g.loser = (j['x'] as num?)?.toInt();
    g._rng = SeededRandom((j['r'] as num).toInt());
    return g;
  }
}

TowerLevel generateTowerLevel(LevelSpec spec) {
  final r = SeededRandom(mixSeed([spec.seed, 1818]));
  final d = spec.difficulty.clamp(1, 10);
  final h = 8 + d + r.nextInt(3);
  final layers = List<int>.filled(h, 7);
  // Biraz yıpranmış bir kule: rastgele katlardan güvenli çekilmiş bloklar.
  final wear = r.nextInt(2 + d);
  for (var k = 0; k < wear; k++) {
    final i = r.nextInt(h - 2);
    final m = layers[i];
    final opts = [for (var b = 0; b < 3; b++) if ((m & (1 << b)) != 0 && stableMask(m & ~(1 << b))) b];
    if (opts.isEmpty) continue;
    layers[i] = m & ~(1 << opts[r.nextInt(opts.length)]);
  }
  return TowerLevel(layers: layers, seed: spec.seed, difficulty: d);
}
