import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hophop/widgets/call_grid.dart';

/// Görüşme ızgarasının yerleşimi. Bu düzen elde yazıldığı için (GridView.count
/// dikey telefonda iki kişiyi ince şeritlere çeviriyordu) satır/sütun dağılımı
/// ve son satırın ortalanması testle sabitleniyor.
void main() {
  const screen = Size(400, 800);

  /// [n] karoyu yerleştirir ve her karonun ekrandaki dikdörtgenini döner.
  Future<List<Rect>> layout(WidgetTester tester, int n) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CallGrid(
          tiles: [
            for (var i = 0; i < n; i++)
              SizedBox.expand(key: ValueKey('tile$i'), child: const Placeholder()),
          ],
        ),
      ),
    );
    return [
      for (var i = 0; i < n; i++)
        tester.getRect(find.byKey(ValueKey('tile$i'))),
    ];
  }

  testWidgets('2 kişi alt alta — yan yana konunca şeride dönüyorlardı',
      (tester) async {
    final r = await layout(tester, 2);
    expect(r[0].width, screen.width);
    expect(r[1].width, screen.width);
    expect(r[0].top, 0);
    expect(r[1].top, screen.height / 2);
  });

  testWidgets('3 kişi: üstte 2, altta 1 ve ortalanmış', (tester) async {
    final r = await layout(tester, 3);
    expect(r[0].width, screen.width / 2);
    // İlk satır iki karo yan yana
    expect(r[0].left, 0);
    expect(r[1].left, screen.width / 2);
    // Tek kalan alttaki karo ortada
    expect(r[2].top, screen.height / 2);
    expect(r[2].center.dx, screen.width / 2);
  });

  testWidgets('4 kişi: 2 + 2', (tester) async {
    final r = await layout(tester, 4);
    expect(r.map((e) => e.width).toSet(), {screen.width / 2});
    expect(r[2].top, screen.height / 2);
    expect(r[2].left, 0);
    expect(r[3].left, screen.width / 2);
  });

  testWidgets('5 kişi: üstte 3, altta 2 ve ortalanmış', (tester) async {
    final r = await layout(tester, 5);
    // Genişlikler kayan nokta yuvarlamasıyla son basamakta ayrışıyor.
    for (final rect in r) {
      expect(rect.width, closeTo(screen.width / 3, 0.01));
    }
    expect(r[0].left, 0);
    expect(r[2].top, 0);
    // Alt satırdaki iki karo birlikte ortalanır: sol kenar tam bir karo eni
    // kadar içeride başlar.
    expect(r[3].top, screen.height / 2);
    expect(r[3].left, closeTo(screen.width / 6, 0.01));
    expect(r[4].right, closeTo(screen.width * 5 / 6, 0.01));
  });

  testWidgets('6 kişi: 3 + 3', (tester) async {
    final r = await layout(tester, 6);
    for (final rect in r) {
      expect(rect.width, closeTo(screen.width / 3, 0.01));
    }
    expect(r[3].top, screen.height / 2);
    expect(r[3].left, 0);
    expect(r[5].right, closeTo(screen.width, 0.01));
  });

  test('sütun sayısı: 1-2 tek, 3-4 çift, 5-6 üçlü', () {
    expect(CallGrid.columnsFor(1), 1);
    expect(CallGrid.columnsFor(2), 1);
    expect(CallGrid.columnsFor(3), 2);
    expect(CallGrid.columnsFor(4), 2);
    expect(CallGrid.columnsFor(5), 3);
    expect(CallGrid.columnsFor(6), 3);
  });
}
