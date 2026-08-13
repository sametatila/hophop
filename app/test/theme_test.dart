import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hophop/theme/hop_theme.dart';

void main() {
  // Test ortamında ağ yok — google_fonts indirme denemesi test hatası üretmesin.
  GoogleFonts.config.allowRuntimeFetching = false;

  test('AppBar başlık stili tema nesnesinde doğru', () {
    final adult = hopTheme(HopMode.adult);
    final kid = hopTheme(HopMode.kid);
    debugPrint('adult titleTextStyle: '
        'size=${adult.appBarTheme.titleTextStyle?.fontSize} '
        'weight=${adult.appBarTheme.titleTextStyle?.fontWeight} '
        'family=${adult.appBarTheme.titleTextStyle?.fontFamily}');
    debugPrint('kid   titleTextStyle: '
        'size=${kid.appBarTheme.titleTextStyle?.fontSize} '
        'weight=${kid.appBarTheme.titleTextStyle?.fontWeight}');
    expect(adult.appBarTheme.titleTextStyle?.fontSize, 23);
    expect(kid.appBarTheme.titleTextStyle?.fontSize, 26);
    expect(adult.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w800);
  });

  testWidgets('AppBar başlığı gerçekten büyük çiziliyor', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: hopTheme(HopMode.adult),
      home: Scaffold(appBar: AppBar(title: const Text('Kişiler'))),
    ));
    final text = tester.widget<Text>(find.text('Kişiler'));
    final style = DefaultTextStyle.of(
            tester.element(find.text('Kişiler')))
        .style;
    debugPrint('render: size=${style.fontSize} weight=${style.fontWeight} '
        'explicitStyle=${text.style}');
    expect(style.fontSize, 23);
  });
}
