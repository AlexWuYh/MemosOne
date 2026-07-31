import 'package:flutter_test/flutter_test.dart';
import 'package:memos_one/core/utils/tag_parser.dart';

void main() {
  test('parses hashtags and lowercases', () {
    final tags = parseTags('Hello #Work and #Life/Plan #work');
    expect(tags, ['life/plan', 'work']);
  });

  test('ignores empty content', () {
    expect(parseTags('no tags here'), isEmpty);
  });
}
