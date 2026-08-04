import 'package:flutter_test/flutter_test.dart';
import 'package:memos_one/domain/entities/memo.dart';

void main() {
  test('public url uses /memos/{uid} like web', () {
    expect(
      memosPublicUrl('https://memo.oneone.life', 'memos/9D8vkwwoiNUUqb85Bw6FUC'),
      'https://memo.oneone.life/memos/9D8vkwwoiNUUqb85Bw6FUC',
    );
    expect(
      memosPublicUrl('https://memo.oneone.life/', '9D8vkwwoiNUUqb85Bw6FUC'),
      'https://memo.oneone.life/memos/9D8vkwwoiNUUqb85Bw6FUC',
    );
    expect(
      memosPublicUrl('https://memo.oneone.life', null),
      'https://memo.oneone.life',
    );
  });
}
