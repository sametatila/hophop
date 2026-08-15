import 'package:flutter/widgets.dart';

/// Görüşme ekranındaki katılımcı karolarının yerleşimi.
///
/// NEDEN ELDE YAZILDI: `GridView.count` sabit sütun sayısıyla çiziyordu; dikey
/// telefonda iki kişiyi yan yana koymak karoları ince birer şeride çeviriyordu.
/// Sütun sayısı kişi sayısından gelmeli ve son satır tam dolmuyorsa ortalanmalı:
///
///   1 → tek karo            2 → alt alta
///   3 → üstte 2, altta 1    4 → 2 + 2
///   5 → üstte 3, altta 2    6 → 3 + 3
///
/// (Aramada en fazla 6 kişi olduğu için 6'nın üstü pratikte oluşmaz; oluşursa
/// 3 sütun korunur ve satır sayısı artar.)
class CallGrid extends StatelessWidget {
  final List<Widget> tiles;

  const CallGrid({super.key, required this.tiles});

  /// Verilen karo sayısı için sütun sayısı.
  static int columnsFor(int n) => n <= 2 ? 1 : (n <= 4 ? 2 : 3);

  @override
  Widget build(BuildContext context) {
    final n = tiles.length;
    if (n == 0) return const SizedBox.shrink();
    final cols = columnsFor(n);
    final rows = (n + cols - 1) ~/ cols;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / cols;
        final h = box.maxHeight / rows;
        return Column(
          children: [
            for (var r = 0; r < rows; r++)
              SizedBox(
                height: h,
                child: Row(
                  // Eksik kalan son satır ortada dursun; sola yaslanınca
                  // düzen yamuk görünüyor.
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = r * cols; i < n && i < (r + 1) * cols; i++)
                      SizedBox(width: w, height: h, child: tiles[i]),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
