/// Blok Kule Dengesi: kuleden blok çek, tepeye koy; güvenli hamlesi kalmayan kaybeder.
/// Blok Oyunları merkez uygulamasının oyunu.
library;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';

import 'src/tower_rules.dart';
import 'src/tower_view.dart';

export 'src/tower_engine.dart';
export 'src/tower_rules.dart';

final kuleDengesiConfig = GameConfig(
  gameId: kuleDengesiId,
  title: const ['Denge Kulesi', 'Balance Tower', 'Balanceturm', 'Torre de Equilibrio', 'Tour d\'Équilibre'],
  tagline: const [
    'Blok çek, tepeye koy, kuleyi rakibine yıktır!',
    'Pull, stack, and let your rival topple it!',
    'Ziehen, stapeln, den Gegner fallen lassen!',
    '¡Saca, apila y que caiga tu rival!',
    'Tirez, empilez, faites tomber l\'adversaire !',
  ],
  seedColor: const Color(0xFF8D6E63),
  icon: Icons.align_vertical_bottom_rounded,
  rules: TowerRules(),
  buildPlay: (ctx) => TowerView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.touch_app, [
      'Sırayla bir blok çekersiniz; çekilen blok kendiliğinden tepeye konur.',
      'Take turns pulling a block; it is stacked on top for you.',
      'Abwechselnd einen Block ziehen; er landet oben.',
      'Por turnos saca un bloque; se apila arriba.',
      'Chacun son tour, tirez un bloc ; il va en haut.',
    ]),
    TutorialStep(Icons.balance, [
      'Bir kat ortası ya da iki yanı varsa ayakta kalır. Tepedeki katlara dokunulmaz.',
      'A level stands if its middle or both sides remain. Top levels are off limits.',
      'Eine Ebene hält mit Mitte oder beiden Seiten. Oben ist tabu.',
      'Un nivel aguanta con el centro o ambos lados. Arriba no se toca.',
      'Un niveau tient avec le centre ou les deux côtés. Le haut est interdit.',
    ]),
    TutorialStep(Icons.emoji_events, [
      'Güvenli hamlesi kalmayan kaybeder. İpucu kazandıran hamleyi gösterir.',
      'Whoever has no safe move left loses. A hint shows a winning move.',
      'Wer keinen sicheren Zug hat, verliert.',
      'Quien no tenga jugada segura, pierde.',
      'Celui qui n\'a plus de coup sûr perd.',
    ]),
  ],
);
