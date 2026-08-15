

import 'package:btcc/src/models/exports.dart';
import 'package:flutter/material.dart';

import 'grid_expander.dart';

typedef ExpandCollapseCallback<T extends Object> = void Function(GridList<T>);
typedef CreateItemCallback<T extends Object> = T Function();
typedef GridItemBuilder<T extends Object> = Widget Function(BuildContext, T);
typedef ItemToBoolCallback<T extends Object> = bool Function(T);
typedef IndexItemCallback<T extends Object> = void Function(int, T);
typedef DragItemCallback = void Function(int);
typedef WidgetWrapper<T extends Object> = Widget Function(T, Widget);
typedef OnPictureTaken = void Function(String);
typedef GetDirCallback = Future<String> Function();
typedef WidgetCallback = Widget Function();
typedef AddCastleToGameCallback = Future<void> Function(Castle, String, int);
typedef UpdateCastleCallback = Future<void> Function(Castle);
typedef DeleteCastleCallback = Future<void> Function(Castle);
typedef DeleteGameCallback = Future<void> Function(Game);
typedef RearrangedCastlesCallback = void Function(int, int);
typedef GetCastleColorCallback = Color Function(Castle);
typedef DragTargetAcceptWithScrollControllerCallback<T extends Object> = Function(DragTargetDetails<T>, ScrollController);