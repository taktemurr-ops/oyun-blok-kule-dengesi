import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/core/strings.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/app/studio_ui.dart';

import 'tower_engine.dart';
import 'tower_rules.dart';

final Map<StudioLook, ThemeData> _studioThemes = {};

class TowerView extends StatefulWidget {
  final PlayContext ctx;
  const TowerView({super.key, required this.ctx});

  @override
  State<TowerView> createState() => _TowerViewState();
}

class _TowerViewState extends State<TowerView> {
  late TowerLevel level;
  late TowerGame game;
  (int, int)? _hint;
  (int, int)? _shake;
  (int, int)? _last;
  int _seconds = 0, _hints = 0;
  Timer? _timer, _aiTimer;
  bool _ended = false;
  String? _msg;
  double _bw = 40, _bh = 20;

  PlayContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<TowerLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? TowerGame.restore(level, snap) : TowerGame(level);
    _seconds = (ctx.resume['secs'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ended && mounted) setState(() => _seconds++);
    });
    if (game.turn == 1 && !game.over) _scheduleAi();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _aiTimer?.cancel();
    super.dispose();
  }

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': _seconds, 'hints': _hints});

  void _tapBlock(int i, int k) {
    if (_ended || game.turn != 0) return;
    if (!game.safe(i, k)) {
      ctx.sfx(Sfx.error);
      setState(() {
        _shake = (i, k);
        _msg = !game.removable(i)
            ? (Strings.tx(ctx.lang, 'Tepedeki katlara dokunulmaz.', 'Top levels can\'t be touched.'))
            : (Strings.tx(ctx.lang, 'Bu blok kuleyi taşıyor!', 'This block holds the tower!'));
      });
      Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _shake = null);
      });
      return;
    }
    game.move(i, k);
    ctx.sfx(Sfx.place);
    setState(() {
      _hint = null;
      _msg = null;
      _last = (i, k);
    });
    _persist();
    if (game.over) {
      _end();
    } else {
      _scheduleAi();
    }
  }

  void _scheduleAi() {
    _aiTimer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted || game.over) return;
      final m = game.computerMove();
      if (m == null) return;
      game.move(m.$1, m.$2);
      ctx.sfx(Sfx.tap);
      setState(() => _last = m);
      _persist();
      if (game.over) _end();
    });
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    final won = game.loser == 1;
    ctx.sfx(won ? Sfx.win : Sfx.lose);
    setState(() => _msg = won
        ? (Strings.tx(ctx.lang, 'Rakibin güvenli hamlesi kalmadı. Kazandın!', 'No safe move left for the rival. You win!'))
        : (Strings.tx(ctx.lang, 'Güvenli hamlen kalmadı, kule yıkıldı.', 'No safe move left. The tower falls.')));
    Timer(const Duration(milliseconds: 900), () {
      ctx.finish(RoundResult(
        won: won,
        score: won ? 200 + game.moves * 10 - _hints * 30 : game.moves * 5,
        stars: TowerRules.stars(game, _hints),
        seconds: _seconds,
        moves: game.moves,
        hintsUsed: _hints,
        undosUsed: 0,
        gameStats: {'towers_won': won ? 1 : 0, 'blocks_pulled': (game.moves + 1) ~/ 2},
      ));
    });
  }

  Future<void> _useHint() async {
    if (game.turn != 0 || _ended) return;
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => _hint = game.winningMove() ?? (game.safeMoves().isEmpty ? null : game.safeMoves().first));
    _persist();
  }

  /// Oyun içi düğmeler, çipler ve yazılar onaylı koyu tasarımda (merkezin
  /// paleti); tahta çizimi kendi renklerini korur.
  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    return Theme(data: _studioThemes[look] ??= buildStudioTheme(look), child: Builder(builder: _build));
  }

  Widget _build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final n = game.layers.length + 2;
      _bh = math.max(10.0, math.min(cons.maxHeight * 0.74 / n, 30.0));
      _bw = math.min(_bh * 3.2, (cons.maxWidth - 40) / 3);
      final yourTurn = game.turn == 0 && !_ended;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Icon(yourTurn ? Icons.person : Icons.smart_toy_outlined, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  _msg ??
                      (yourTurn
                          ? (Strings.tx(ctx.lang, 'Sıra sende: güvenli bir blok çek', 'Your turn: pull a safe block'))
                          : (Strings.tx(ctx.lang, 'Rakip düşünüyor…', 'Rival is thinking…'))),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const Icon(Icons.timer_outlined, size: 18),
            Text(' ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'),
          ]),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTapUp: (d) {
                final w = _bw * 3, h = _bh * game.layers.length;
                final x = d.localPosition.dx, y = d.localPosition.dy - (_bh * 2);
                if (x < 0 || x >= w || y < 0 || y >= h) return;
                final i = game.layers.length - 1 - (y / _bh).floor();
                final k = (x / _bw).floor();
                if ((game.layers[i] & (1 << k)) != 0) _tapBlock(i, k);
              },
              child: Semantics(
                label: 'tower',
                child: SizedBox(
                  width: _bw * 3,
                  height: _bh * (game.layers.length + 2),
                  child: CustomPaint(painter: _Painter(this)),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IconButton.filledTonal(onPressed: yourTurn ? _useHint : null, icon: const Icon(Icons.lightbulb), tooltip: ctx.t('hint')),
        ),
      ]);
    });
  }
}

class _Painter extends CustomPainter {
  final _TowerViewState v;
  _Painter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final g = v.game;
    final bw = v._bw, bh = v._bh;
    final n = g.layers.length;
    const woodA = Color(0xFFC8A27A), woodB = Color(0xFFB88B5E), locked = Color(0xFF9C8068);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-bw * 0.2, size.height - 6, bw * 3.4, 6), const Radius.circular(3)),
        Paint()..color = Colors.black26);
    for (var i = 0; i < n; i++) {
      final m = g.layers[i];
      final y = (n - 1 - i) * bh + bh * 2;
      for (var k = 0; k < 3; k++) {
        if ((m & (1 << k)) == 0) continue;
        var r = Rect.fromLTWH(k * bw, y, bw, bh).deflate(1.2);
        if (v._shake == (i, k)) r = r.shift(const Offset(4, 0));
        final base = !g.removable(i) ? locked : (i.isEven ? woodA : woodB);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(bh * 0.18)), Paint()..color = base);
        // Damar çizgileri
        final grain = Paint()
          ..color = Colors.black.withValues(alpha: 0.08)
          ..strokeWidth = 1;
        canvas.drawLine(r.centerLeft.translate(4, -bh * 0.15), r.centerRight.translate(-4, -bh * 0.15), grain);
        canvas.drawLine(r.centerLeft.translate(6, bh * 0.18), r.centerRight.translate(-8, bh * 0.18), grain);
        if (v._last == (i, k)) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(r, Radius.circular(bh * 0.18)),
              Paint()
                ..color = Colors.white70
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
        }
        if (v._hint == (i, k)) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(r.inflate(1), Radius.circular(bh * 0.18)),
              Paint()
                ..color = Colors.amber
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
