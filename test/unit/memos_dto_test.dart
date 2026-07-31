import 'package:flutter_test/flutter_test.dart';
import 'package:memos_one/domain/entities/memo.dart';
import 'package:memos_one/infrastructure/network/memos/memos_api_client.dart';

void main() {
  test('maps remote memo json', () {
    final dto = RemoteMemoDto.fromJson({
      'name': 'memos/1',
      'content': 'hi',
      'visibility': 'PUBLIC',
      'pinned': true,
      'state': 'NORMAL',
      'createTime': '2024-01-01T00:00:00Z',
      'updateTime': '2024-01-02T00:00:00Z',
    });
    expect(dto.name, 'memos/1');
    expect(dto.visibility, MemoVisibility.public);
    expect(dto.pinned, isTrue);
    expect(dto.archived, isFalse);
    expect(dto.updateTime, isNotNull);
  });
}
