import 'package:flutter/cupertino.dart';

class AppListView extends StatelessWidget {
  const AppListView({
    required this.children,
    this.controller,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    super.key,
  }) : itemBuilder = null,
       separatorBuilder = null,
       itemCount = null;

  const AppListView.builder({
    required IndexedWidgetBuilder this.itemBuilder,
    required int this.itemCount,
    this.controller,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    super.key,
  }) : children = null,
       separatorBuilder = null;

  const AppListView.separated({
    required IndexedWidgetBuilder this.itemBuilder,
    required int this.itemCount,
    required IndexedWidgetBuilder this.separatorBuilder,
    this.controller,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    super.key,
  }) : children = null;

  final List<Widget>? children;
  final IndexedWidgetBuilder? itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final int? itemCount;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  static const ScrollPhysics bouncingPhysics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  @override
  Widget build(BuildContext context) {
    if (children != null) {
      return ListView(
        controller: controller,
        padding: padding,
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        keyboardDismissBehavior: keyboardDismissBehavior,
        physics: bouncingPhysics,
        children: children!,
      );
    }

    if (separatorBuilder != null) {
      return ListView.separated(
        controller: controller,
        padding: padding,
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        keyboardDismissBehavior: keyboardDismissBehavior,
        physics: bouncingPhysics,
        itemBuilder: itemBuilder!,
        separatorBuilder: separatorBuilder!,
        itemCount: itemCount!,
      );
    }

    return ListView.builder(
      controller: controller,
      padding: padding,
      scrollDirection: scrollDirection,
      reverse: reverse,
      shrinkWrap: shrinkWrap,
      keyboardDismissBehavior: keyboardDismissBehavior,
      physics: bouncingPhysics,
      itemBuilder: itemBuilder!,
      itemCount: itemCount!,
    );
  }
}
