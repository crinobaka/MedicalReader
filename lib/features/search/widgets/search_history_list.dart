import 'package:flutter/material.dart';

/// Recent-search presentation. The widget deliberately knows nothing about
/// persistence; the caller owns the history source and actions.
class SearchHistoryList extends StatelessWidget {
  const SearchHistoryList({
    super.key,
    required this.history,
    required this.onSelected,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('最近搜索', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
        ),
        for (final item in history)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.north_west, size: 18),
            onTap: () => onSelected(item),
          ),
      ],
    );
  }
}
