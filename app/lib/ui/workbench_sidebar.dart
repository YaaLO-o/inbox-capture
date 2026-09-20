import 'package:flutter/material.dart';

/// A sidebar that responds to the width of its own shell, not the viewport.
class WorkbenchSidebar extends StatefulWidget {
  final Widget sidebar;
  final Widget child;
  final double collapseBelow;
  final double sidebarWidth;

  const WorkbenchSidebar({
    super.key,
    required this.sidebar,
    required this.child,
    this.collapseBelow = 600,
    this.sidebarWidth = 240,
  });

  @override
  State<WorkbenchSidebar> createState() => _WorkbenchSidebarState();
}

class _WorkbenchSidebarState extends State<WorkbenchSidebar> {
  bool _open = true;
  bool? _previousNarrow;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < widget.collapseBelow;
        if (_previousNarrow != narrow) {
          final first = _previousNarrow == null;
          _previousNarrow = narrow;
          if (!first || narrow) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _open != !narrow) {
                setState(() => _open = !narrow);
              }
            });
          }
        }

        Widget withScope(Widget child) => WorkbenchSidebarScope(
          open: _open,
          narrow: narrow,
          toggle: _toggle,
          child: child,
        );
        final content = withScope(widget.child);
        final sidebar = withScope(widget.sidebar);

        if (narrow) {
          return Stack(
            children: [
              Positioned.fill(child: content),
              if (_open) ...[
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('sidebar-scrim'),
                    onTap: _toggle,
                    child: Container(color: Colors.black54),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: widget.sidebarWidth,
                    height: double.infinity,
                    child: sidebar,
                  ),
                ),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_open) ...[
              SizedBox(width: widget.sidebarWidth, child: sidebar),
              const VerticalDivider(width: 1),
            ],
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

/// Read by toolbar controls inside [WorkbenchSidebar.child].
class WorkbenchSidebarScope extends InheritedWidget {
  final bool open;
  final bool narrow;
  final VoidCallback toggle;

  const WorkbenchSidebarScope({
    super.key,
    required this.open,
    required this.narrow,
    required this.toggle,
    required super.child,
  });

  static WorkbenchSidebarScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<WorkbenchSidebarScope>();
    assert(scope != null, 'WorkbenchSidebarScope is missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(WorkbenchSidebarScope oldWidget) =>
      open != oldWidget.open || narrow != oldWidget.narrow;
}
