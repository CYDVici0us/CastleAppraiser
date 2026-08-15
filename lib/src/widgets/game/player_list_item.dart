import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class PlayerListItem extends StatelessWidget {
  final String name;
  final int? score;
  final bool isWinner;
  final bool isBench;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final Key? key;

  PlayerListItem({
    required this.name,
    this.score,
    this.isWinner = false,
    this.isBench = false,
    this.onRename,
    this.onDelete,
    this.key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: isWinner
          ? Colors.green.shade700
          : (isBench ? Colors.blueGrey.shade700 : Colors.indigo.shade600),
      child: InkWell(
        onTap: onRename,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: AutoSizeText(
                  name,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (score != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '$score',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              if (isWinner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Winner',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (isBench && onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Delete player',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              const SizedBox(width: 4),
              const Icon(Icons.drag_handle, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
