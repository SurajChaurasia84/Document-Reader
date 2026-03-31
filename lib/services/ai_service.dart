class AiService {
  Future<String> summarizeText(String text) async {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'No text available for summarization.';
    }

    final sentences = normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((sentence) => sentence.trim().isNotEmpty)
        .toList();

    if (sentences.length <= 3) {
      return sentences.join(' ');
    }

    return <String>[
      sentences.first,
      sentences[sentences.length ~/ 2],
      sentences.last,
    ].join(' ');
  }

  Future<String> translateText(
    String text, {
    String targetLanguage = 'Hindi',
  }) async {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'No text available for translation.';
    }

    return '[$targetLanguage]\n$normalized';
  }
}
