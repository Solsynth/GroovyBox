import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:material_ui/material_ui.dart';

/// The page's own scroll view is the only thing that consumes the published
/// chrome measurement, so this is where "the last row clears the glass" is
/// observable without standing up the router and its shell.
void main() {
  testWidgets('PageListView reserves the clearance the shell publishes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: createAppThemeSet().light,
        home: SolChromeInset(
          inset: 132,
          barOffset: 100,
          child: Scaffold(
            body: PageListView(
              children: [
                const SizedBox(height: 40),
                // The last row a reader must still be able to tap.
                Container(
                  key: const ValueKey('floor'),
                  height: 40,
                  color: const Color(0xFF00FF00),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = tester.widget<ListView>(find.byType(ListView));
    expect(scroll.padding, const EdgeInsets.only(bottom: 132));
    expect(find.byKey(const ValueKey('floor')), findsOneWidget);
  });

  testWidgets('PageScrollView ends with the published clearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: createAppThemeSet().light,
        home: SolChromeInset(
          inset: 132,
          barOffset: 100,
          child: Scaffold(
            body: PageScrollView(
              extraBottom: 50,
              slivers: const [
                SliverToBoxAdapter(
                  child: SizedBox(
                    key: ValueKey('floor'),
                    height: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The inner box is the scroll view's own floor, sized from the
    // published inset plus the page's extra bar.
    final sized = tester.widgetList<SizedBox>(find.byType(SizedBox));
    expect(
      sized.any((box) => box.height == 182),
      isTrue,
      reason: 'the floor must be the chrome plus the page bar',
    );
  });

}
