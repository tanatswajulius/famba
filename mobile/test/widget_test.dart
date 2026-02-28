import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:famba_rider/main.dart';
import 'package:famba_rider/core/app_state.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const FambaApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Famba'), findsWidgets);
  });
}
