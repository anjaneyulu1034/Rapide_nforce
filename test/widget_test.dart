import 'package:flutter_test/flutter_test.dart';
import 'package:rapide_nforce/main.dart';

void main() {
  testWidgets('Login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const RapideNforceApp());

    expect(find.text('RAPIDE'), findsOneWidget);
    expect(find.text('Technician Login'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Demo credentials'), findsOneWidget);
  });
}
