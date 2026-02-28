import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:famba_driver/main.dart';
import 'package:famba_driver/core/driver_state.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DriverState(),
      child: const FambaDriverApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Famba'), findsWidgets);
  });
}
