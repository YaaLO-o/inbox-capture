import 'package:flutter/material.dart';

/// 桌宠旁边弹出的极简快捷菜单。
///
/// 固定浅色背景 + 深色文字，不跟随系统 Dark Mode，
/// 避免透明窗口下文字与背景同色导致不可读。
/// 宽度与桌宠窗口一致（132），展开时窗口仅向下增高。
class PetPopupMenu extends StatelessWidget {
  final VoidCallback? onOpenControlCenter;
  final VoidCallback? onSelectVault;
  final VoidCallback? onCheckUpdates;
  final VoidCallback? onQuit;

  const PetPopupMenu({
    super.key,
    this.onOpenControlCenter,
    this.onSelectVault,
    this.onCheckUpdates,
    this.onQuit,
  });

  static const double menuWidth = 132;
  static const double itemHeight = 44;
  static const double menuHeight = itemHeight * 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: menuWidth,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuItem(
            label: '控制中心',
            onTap: onOpenControlCenter,
            showDivider: true,
          ),
          _MenuItem(
            label: '更改存储文件夹',
            onTap: onSelectVault,
            showDivider: true,
          ),
          _MenuItem(
            label: '检查更新',
            onTap: onCheckUpdates,
            showDivider: true,
          ),
          _MenuItem(
            label: '退出 INbox',
            onTap: onQuit,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool isDestructive;

  const _MenuItem({
    required this.label,
    this.onTap,
    this.showDivider = false,
    this.isDestructive = false,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDivider)
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE8E8E8)),
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: PetPopupMenu.itemHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              color: _hovering
                  ? const Color(0xFFF0F0F0)
                  : Colors.transparent,
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDestructive
                      ? const Color(0xFFD9534F)
                      : const Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
