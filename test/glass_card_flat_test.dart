import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/design/widgets.dart';

/// FLAG #25: kart başına BackdropFilter yok; ekranda tek blur katmanı
/// glass_layer.dart'tan gelir, GlassCard yarı saydam düz dolgudur.
void main() {
  testWidgets('GlassCard contains no BackdropFilter', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              GlassCard(child: Text('a')),
              GlassCard(child: Text('b')),
              GlassCard(child: Text('c')),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(GlassCard), findsNWidgets(3));
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
