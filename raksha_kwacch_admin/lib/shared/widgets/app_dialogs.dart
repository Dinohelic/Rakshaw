import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'app_button.dart';

class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    required this.onConfirm,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: AppColors.textSlate),
      ),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.outlined,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        AppButton(
          label: confirmLabel,
          variant: isDestructive
              ? AppButtonVariant.destructive
              : AppButtonVariant.primary,
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
        ),
      ],
    );
  }
}

class AppDetailDrawer extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const AppDetailDrawer({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 400,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(child: child),
          if (actions != null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: a,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
