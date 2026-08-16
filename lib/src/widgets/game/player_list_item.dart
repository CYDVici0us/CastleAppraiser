import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class PlayerListItem extends StatelessWidget {
  final String name;
  final int? score;
  final bool isWinner;
  final bool isBench;
  /// `-1` castle above, `1` castle below, `0` tie, `null` hidden.
  final int? primaryCastleDirection;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final Key? key;

  PlayerListItem({
    required this.name,
    this.score,
    this.isWinner = false,
    this.isBench = false,
    this.primaryCastleDirection,
    this.onRename,
    this.onDelete,
    this.key,
  }) : super(key: key);

  Widget? _primaryArrow() {
    final dir = primaryCastleDirection;
    if (dir == null) return null;

    if (dir < 0) {
      return const Tooltip(
        message: 'Primary score: castle above',
        child: Icon(Icons.arrow_upward, color: Colors.white, size: 20),
      );
    }
    if (dir > 0) {
      return const Tooltip(
        message: 'Primary score: castle below',
        child: Icon(Icons.arrow_downward, color: Colors.white, size: 20),
      );
    }
    return const Tooltip(
      message: 'Tied adjacent castle scores',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward, color: Colors.white70, size: 16),
          Icon(Icons.arrow_downward, color: Colors.white70, size: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arrow = _primaryArrow();

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
              const Icon(Icons.person, color: Colors.white, size: 22),
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
              if (arrow != null) ...[
                arrow,
                const SizedBox(width: 6),
              ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
