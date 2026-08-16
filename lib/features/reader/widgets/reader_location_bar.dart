import 'package:flutter/material.dart';

class ReaderLocationBar extends StatelessWidget {
  final String location;

  final String? searchLocation;

  const ReaderLocationBar({
    super.key,
    required this.location,
    this.searchLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          location,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (searchLocation != null) ...[
          const SizedBox(height: 2),
          Text(
            searchLocation!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ],
    );
  }
}