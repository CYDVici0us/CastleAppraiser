

import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/typedefs.dart';

typedef GridListValidItemCheck<T> = bool Function(T);
typedef GridListItemDeserializer<T> = List<T> Function(List<String>);

class GridList<T extends Object> {
  final int width;
  final List<T> items;

  GridList(this.width, this.items);

  int get height => items.length~/width;
  int get maxDimension => width > height ? width : height;

  Map toMap() {
    return {
      'width': width,
      'items': items,
    };
  }

  String toString() {
    return this.toMap().toString();
  }

  String toDetailedString({bool withNewLines=true}) {
    String result = '';
    var appendStr = (str) {
      result = result + str + (withNewLines ? '\n' : '');
    };
    appendStr('width: $width');
    for (int i = 0; i < items.length; i++) {
      int x = i%width;
      int y = i~/width;
      appendStr('#$i, ($x, $y): ${items[i]}');
    }

    return result;
  }

  @override
  int get hashCode {
    int hash = width.hashCode;
    for (int i = 0; i < items.length; i++) {
      hash += (items[i].hashCode + i.hashCode);
    }
    return hash;
  }

  @override
  bool operator==(Object other) {
    if (other is GridList) {
      if (other.width == this.width && other.height == this.height) {
        for (int i = 0; i < this.items.length; i++) {
          if (other.items[i] != this.items[i]) {
            return false;
          }
        }

        return true;
      }
    }

    return false;
  }

  static GridList<T> fromMap<T extends Object>(Map map, GridListItemDeserializer<T> deserializer) {
    return new GridList<T>(
      map['width'],
      deserializer(map['items'])
    );
  }

  T getAt(int x, int y) {
    return items[x + y*width];
  }
  
  bool isOnBorder(T item) {
    log('here');
    for (int i = 0; i < items.length; i++) {
      bool topRow = i/width == 0;
      bool rightColumn = i%width == width-1;
      bool bottomRow = i >= items.length-width;
      bool leftColumn = i%width == 0;
      if (topRow || rightColumn || bottomRow || leftColumn) {
        if (item == items[i]) {
          return true;
        }
      }
    }
    return false;
  }
}

class GridListExpander<T extends Object> {
  final GridList<T> input;
  final GridListValidItemCheck<T> isNonBlankNonEmpty;
  final CreateItemCallback<T> getEmpty;

  bool addNewFirstRow = false;
  bool addNewLastColumn = false;
  bool addNewLastRow = false;
  bool addNewFirstColumn = false;

  bool removeFirstRow = true;
  bool removeLastColumn = true;
  bool removeLastRow = true;
  bool removeFirstColumn = true;

  GridListExpander(this.input, this.isNonBlankNonEmpty, this.getEmpty) {

    _initForExpand();
    // _initForCollapse();
  }

  void _initForCollapse() {
    for (int i = 0; i < input.items.length; i++) {

      bool isTopRow = (i < input.width);
      bool isRightColumn = (i % input.width == (input.width-1));
      bool isBottomRow = (i > (input.items.length-input.width));
      bool isLeftColumn = (i % input.width == 0);
      T item = input.items[i];

      //print('$i, ==> $isTopRow, $isRightColumn, $isBottomRow, $isLeftColumn');

      if (isTopRow && !isNonBlankNonEmpty(item)) {
        removeFirstRow = false;
        return;
      }

      if (isRightColumn && !isNonBlankNonEmpty(item)) {
        removeLastColumn = false;
        return;
      }

      if (isBottomRow && !isNonBlankNonEmpty(item)) {
        removeLastRow = false;
        return;
      }

      if (isLeftColumn && !isNonBlankNonEmpty(item)) {
        removeFirstColumn = false;
        return;
      }

      //print('$i, ==> $isTopRow, $isRightColumn, $isBottomRow, $isLeftColumn -- $addNewFirstRow, $addNewLastColumn, $addNewLastRow, $addNewLastColumn');
    }
  }

  void _initForExpand() {
    for (int i = 0; i < input.items.length; i++) {

      bool isTopRow = (i < input.width);
      bool isRightColumn = (i % input.width == (input.width-1));
      bool isBottomRow = (i > (input.items.length-input.width));
      bool isLeftColumn = (i % input.width == 0);
      T item = input.items[i];

      //print('$i, ==> $isTopRow, $isRightColumn, $isBottomRow, $isLeftColumn');

      if (isTopRow && isNonBlankNonEmpty(item)) {
        addNewFirstRow = true;
        return;
      }

      if (isRightColumn && isNonBlankNonEmpty(item)) {
        addNewLastColumn = true;
        return;
      }

      if (isBottomRow && isNonBlankNonEmpty(item)) {
        addNewLastRow = true;
        return;
      }

      if (isLeftColumn && isNonBlankNonEmpty(item)) {
        addNewFirstColumn = true;
        return;
      }

      //print('$i, ==> $isTopRow, $isRightColumn, $isBottomRow, $isLeftColumn -- $addNewFirstRow, $addNewLastColumn, $addNewLastRow, $addNewLastColumn');
    }
  }

  bool shouldChange() {
    var result = addNewFirstRow || addNewLastColumn || addNewLastRow || addNewFirstColumn;
             //||  removeFirstRow || removeLastColumn || removeLastRow || removeFirstColumn;
    //log('shouldChange = $result');
    return result;
  }

  GridList<T> change() {
    int oldLength = input.items.length;
    int oldWidth = input.width;
    int newWidth = input.width + (addNewFirstColumn ? 1 : 0) + (addNewLastColumn ? 1 : 0); // + (removeFirstColumn ? -1 : 0) + (removeLastColumn ? -1 : 0);
    int oldHeight = oldLength ~/ input.width;
    int newHeight = oldHeight + (addNewFirstRow ? 1 : 0) + (addNewLastRow ? 1 : 0);
    int newLength = newWidth * newHeight;
    List<T> newList = new List.generate(newLength, (index) => getEmpty());

    if (addNewFirstRow) {
      for (int i = 0; i < oldLength; i++) {
        int newIndex = i + newWidth;
        //print('$i => $newIndex');
        newList[newIndex] = input.items[i];
      }
    }
    else if (addNewLastColumn) {
      for (int i = oldWidth; i < oldLength; i++) {
        int newIndex = i + (i~/oldWidth);
        //print('$i => $newIndex');
        newList[newIndex] = input.items[i];
      }
    }
    else if (addNewLastRow) {
      for (int i = 0; i < oldLength; i++) {
        newList[i] = input.items[i];
      }
    }
    else if (addNewFirstColumn) {
      for (int i = oldWidth; i < oldLength; i++) {
        int newIndex = i + 1+ (i~/oldWidth);
        //print('$i => $newIndex');
        newList[newIndex] = input.items[i];
      }
    }

    return new GridList(newWidth, newList);
  }
}

/// Result of fitting a grid to occupied tiles plus a one-cell empty perimeter.
class GridNormalizeResult<T extends Object> {
  final GridList<T> grid;
  final int contentMinX;
  final int contentMinY;
  final int oldWidth;
  final bool changed;

  GridNormalizeResult({
    required this.grid,
    required this.contentMinX,
    required this.contentMinY,
    required this.oldWidth,
    required this.changed,
  });

  /// Maps an index from the pre-normalize grid into the normalized grid.
  /// Returns null if the old cell falls outside the new bounds.
  int? mapIndex(int oldIndex) {
    final oldX = oldIndex % oldWidth;
    final oldY = oldIndex ~/ oldWidth;
    final newX = oldX - contentMinX + 1;
    final newY = oldY - contentMinY + 1;
    if (newX < 0 || newY < 0 || newX >= grid.width || newY >= grid.height) {
      return null;
    }
    return newX + newY * grid.width;
  }
}

class GridListNormalizer {
  /// Rebuilds [input] so occupied cells sit in a tight bounding box with exactly
  /// one empty cell of padding on every side.
  static GridNormalizeResult<T> normalizePerimeter<T extends Object>(
    GridList<T> input, {
    required GridListValidItemCheck<T> isOccupied,
    required CreateItemCallback<T> getEmpty,
  }) {
    int? minX, maxX, minY, maxY;
    for (int i = 0; i < input.items.length; i++) {
      if (!isOccupied(input.items[i])) continue;
      final x = i % input.width;
      final y = i ~/ input.width;
      minX = minX == null ? x : (x < minX ? x : minX);
      maxX = maxX == null ? x : (x > maxX ? x : maxX);
      minY = minY == null ? y : (y < minY ? y : minY);
      maxY = maxY == null ? y : (y > maxY ? y : maxY);
    }

    if (minX == null || maxX == null || minY == null || maxY == null) {
      return GridNormalizeResult(
        grid: input,
        contentMinX: 0,
        contentMinY: 0,
        oldWidth: input.width,
        changed: false,
      );
    }

    final newWidth = (maxX - minX + 1) + 2;
    final newHeight = (maxY - minY + 1) + 2;
    final alreadyTight = minX == 1 &&
        minY == 1 &&
        maxX == input.width - 2 &&
        maxY == input.height - 2 &&
        newWidth == input.width &&
        newHeight == input.height;

    if (alreadyTight) {
      return GridNormalizeResult(
        grid: input,
        contentMinX: minX,
        contentMinY: minY,
        oldWidth: input.width,
        changed: false,
      );
    }

    final newItems = List<T>.generate(newWidth * newHeight, (_) => getEmpty());
    for (int i = 0; i < input.items.length; i++) {
      if (!isOccupied(input.items[i])) continue;
      final x = i % input.width;
      final y = i ~/ input.width;
      final newIndex = (x - minX + 1) + (y - minY + 1) * newWidth;
      newItems[newIndex] = input.items[i];
    }

    return GridNormalizeResult(
      grid: GridList<T>(newWidth, newItems),
      contentMinX: minX,
      contentMinY: minY,
      oldWidth: input.width,
      changed: true,
    );
  }

  /// Empty cell orthogonally adjacent to at least one occupied cell.
  static bool canPlaceAdjacent<T extends Object>(
    GridList<T> grid,
    int index, {
    required GridListValidItemCheck<T> isOccupied,
  }) {
    if (index < 0 || index >= grid.items.length) return false;
    if (isOccupied(grid.items[index])) return false;

    final x = index % grid.width;
    final y = index ~/ grid.width;
    const neighbors = [
      [0, -1],
      [0, 1],
      [-1, 0],
      [1, 0],
    ];
    for (final d in neighbors) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (nx < 0 || ny < 0 || nx >= grid.width || ny >= grid.height) continue;
      if (isOccupied(grid.items[nx + ny * grid.width])) return true;
    }
    return false;
  }
}