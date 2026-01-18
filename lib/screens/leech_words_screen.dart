import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/base_providers.dart';
import '../session/session_models.dart';
import '../models/word.dart';

class LeechWordsScreen extends ConsumerStatefulWidget {
  const LeechWordsScreen({super.key});

  @override
  ConsumerState<LeechWordsScreen> createState() => _LeechWordsScreenState();
}

class _LeechWordsScreenState extends ConsumerState<LeechWordsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leechWordsAsync = ref.watch(leechWordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('不熟悉单词'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(leechWordsProvider);
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(theme),
          _buildSearchBar(theme),
          Expanded(
            child: leechWordsAsync.when(
              data: (words) => _buildWordsList(words, theme),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('加载失败', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(leechWordsProvider);
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final leechWordsAsync = ref.watch(leechWordsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          leechWordsAsync.when(
            data: (words) {
              final filteredWords = _getFilteredWords(words);
              return Column(
                children: [
                  Text(
                    '${filteredWords.length}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '个不熟悉单词',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (filteredWords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startLeechTest(filteredWords),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('开始测试'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => Column(
              children: [
                Text(
                  '加载中...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            error: (_, __) => Text(
              '加载失败',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索单词...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: theme.colorScheme.surface,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildWordsList(List<Word> words, ThemeData theme) {
    final filteredWords = _getFilteredWords(words);

    if (filteredWords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.celebration,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '没有找到匹配的单词' : '太棒了！没有不熟悉的单词',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '尝试使用不同的关键词搜索',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredWords.length,
      itemBuilder: (context, index) {
        final word = filteredWords[index];
        return _buildWordCard(word, theme);
      },
    );
  }

  Widget _buildWordCard(Word word, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          word.headword,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (word.pos.isNotEmpty)
              Text(
                word.pos,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              word.primaryDefinition,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '级别: ${word.level}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'mark_known') {
              _markWordAsKnown(word);
            } else if (value == 'details') {
              _showWordDetails(word);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_known',
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('标记为已掌握'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'details',
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('查看详情'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Word> _getFilteredWords(List<Word> words) {
    if (_searchQuery.isEmpty) {
      return words;
    }

    final query = _searchQuery.toLowerCase();
    return words.where((word) {
      return word.headword.toLowerCase().contains(query) ||
          word.primaryDefinition.toLowerCase().contains(query) ||
          word.pos.toLowerCase().contains(query);
    }).toList();
  }

  void _startLeechTest(List<Word> words) {
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有可测试的单词'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 创建不熟悉单词测试的配置
    final settings = ref.read(appSettingsProvider);
    final config = SessionConfig(
      levels: settings.selectedLevelsSet,
      wordsPerSession: words.length.clamp(10, 50), // 限制在10-50个单词之间
      timeLimitMs: settings.timeLimitMs,
      orderPolicy: 'random',
      onlyLeeches: true, // 设置为只测试不熟悉单词
      wrongDelay: 1000,
      slowDelay: 500,
      slowThreshold: 2.0,
    );

    // 启动不熟悉单词测试，传递配置参数
    Navigator.of(context).pushNamed('/test', arguments: config);
  }

  void _markWordAsKnown(Word word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('标记为已掌握'),
        content: Text('确定要将"${word.headword}"标记为已掌握吗？这将从不熟悉单词列表中移除该单词。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                // 重置单词的学习状态，相当于标记为已掌握
                final progressRepo = ref.read(progressRepositoryProvider);
                await progressRepo.resetWordProgress(word.id);

                // 刷新不熟悉单词列表
                ref.invalidate(leechWordsProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已将"${word.headword}"标记为已掌握'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('操作失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showWordDetails(Word word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(word.headword),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (word.pos.isNotEmpty) ...[
                Text(
                  '词性',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(word.pos),
                const SizedBox(height: 12),
              ],
              Text(
                '释义',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(word.primaryDefinition),
              const SizedBox(height: 12),
              Text(
                '级别',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(word.level),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
