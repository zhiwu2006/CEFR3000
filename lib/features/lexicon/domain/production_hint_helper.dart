/// 看义拼词三阶渐进式提示算法辅助工具。
///
/// 遵循认知负荷理论，将提示划分为：
/// - Level 0: 无提示，全自主回忆；
/// - Level 1: 辅音骨架（Consonants）；
/// - Level 2: 元音透视（Vowels）与首字母锚定，保留至少 1 个盲点槽位；
/// - Level 3: 全词揭示（Full Reveal）。
class ProductionHintHelper {
  const ProductionHintHelper._();

  static const Set<String> _vowels = {
    'a', 'e', 'i', 'o', 'u',
    'A', 'E', 'I', 'O', 'U',
  };

  /// 判断字符是否为英文字母 (a-z, A-Z)
  static bool isAlpha(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  /// 判断字符是否为元音 (a, e, i, o, u)
  static bool isVowel(String char) => _vowels.contains(char);

  /// 判断字符是否为辅音
  static bool isConsonant(String char) => isAlpha(char) && !isVowel(char);

  /// 根据提示阶梯（0, 1, 2, 3）计算目标词中应当揭示的字符索引集合。
  ///
  /// [word] 目标英文单词或短语（如 "apple", "take off", "state-of-the-art"）
  /// [level] 提示级别：0, 1, 2, 3
  static Set<int> getRevealedIndices(String word, int level) {
    if (level <= 0 || word.isEmpty) return const <int>{};

    final alphaIndices = <int>[];
    final consonantIndices = <int>[];
    final vowelIndices = <int>[];

    for (var i = 0; i < word.length; i++) {
      final char = word[i];
      if (isAlpha(char)) {
        alphaIndices.add(i);
        if (isConsonant(char)) {
          consonantIndices.add(i);
        } else if (isVowel(char)) {
          vowelIndices.add(i);
        }
      }
    }

    if (alphaIndices.isEmpty) return const <int>{};

    // Level 3: 全词揭示
    if (level >= 3) {
      return alphaIndices.toSet();
    }

    // Level 1: 辅音骨架 (若无辅音或辅音极少，保底揭示首字母)
    if (level == 1) {
      final revealed = <int>{...consonantIndices};
      // 如果辅音集合为空（如纯元音词 "I", "a"），或仅包含全部字母，保底露首字母但留后空
      if (revealed.isEmpty && alphaIndices.isNotEmpty) {
        revealed.add(alphaIndices.first);
      }
      // 避免 Level 1 就把所有字母全部露光（如果全是辅音如 "rhythm" 的部分简写）
      if (revealed.length >= alphaIndices.length && alphaIndices.length > 1) {
        revealed.remove(alphaIndices.last);
      }
      return revealed;
    }

    // Level 2: 元音透视 + 首字母锚定，但严守“至少保留 1 个槽位待填”的认知挑战底线
    final revealed = <int>{
      ...vowelIndices,
      if (alphaIndices.isNotEmpty) alphaIndices.first,
    };

    // 确保 Level 2 包含 Level 1 的线索，实现真正的渐进累加
    final l1 = getRevealedIndices(word, 1);
    revealed.addAll(l1);

    // 如果辅音与元音互补导致全部被选，或者集合大小等于所有字母，移出最后 1 个字母留给用户自主拼写
    if (revealed.length >= alphaIndices.length && alphaIndices.length > 1) {
      revealed.remove(alphaIndices.last);
    }

    return revealed;
  }
}
