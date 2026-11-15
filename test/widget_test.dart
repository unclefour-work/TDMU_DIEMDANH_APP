import 'package:flutter_test/flutter_test.dart';

import 'package:app_diem_danh/main.dart';

void main() {
  testWidgets('Kiem tra man hinh dang nhap', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Đăng nhập'), findsOneWidget);

    expect(find.text('0'), findsNothing);
  });
}
