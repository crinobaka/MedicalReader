import 'package:flutter/material.dart';

/// Bottom navigation controls for the Reader page.
///
/// This widget intentionally contains no Reader business logic. Navigation,
/// page mapping, and loading state remain owned by the Reader controller/page.
class ReaderPageControls extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final bool pageLoading;
  final String pageLabel;
  final String? locationLabel;
  final String? searchLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPageTap;

  const ReaderPageControls({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.pageLoading,
    required this.pageLabel,
    this.locationLabel,
    this.searchLabel,
    this.onPrevious,
    this.onNext,
    this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !pageLoading;

    return SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: enabled && canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 16),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: enabled ? onPageTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pageLabel),
                  if (locationLabel != null)
                    Text(
                      locationLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (searchLabel != null)
                    Text(
                      searchLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Next page',
            onPressed: enabled && canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
