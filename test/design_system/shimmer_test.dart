import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/design_system/shimmer.dart';

void main() {
  group('ShimmerLoading and Skeleton Tests', () {
    testWidgets('ChatMessageShimmerList renders animated message bubbles skeleton', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageShimmerList(),
          ),
        ),
      );

      // Verify ShaderMask is active
      expect(find.byType(ShaderMask), findsOneWidget);
      // Verify shimmer list items exist
      expect(find.byType(ChatMessageShimmerList), findsOneWidget);

      // Advance animation slightly
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('ChatConversationShimmerList renders conversation tile skeletons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatConversationShimmerList(count: 4),
          ),
        ),
      );

      expect(find.byType(ChatConversationShimmerList), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('ProfileShimmerSkeleton renders profile skeleton without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileShimmerSkeleton(),
          ),
        ),
      );

      expect(find.byType(ProfileShimmerSkeleton), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });
}
