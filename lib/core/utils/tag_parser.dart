/// Extract `#tag` tokens from markdown content.
List<String> parseTags(String content) {
  final regex = RegExp(r'(?<![\w/])#([\p{L}\p{N}_/-]+)', unicode: true);
  final tags = <String>{};
  for (final match in regex.allMatches(content)) {
    final raw = match.group(1);
    if (raw == null || raw.isEmpty) continue;
    tags.add(raw.toLowerCase());
  }
  return tags.toList()..sort();
}
