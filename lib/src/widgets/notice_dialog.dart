import 'package:flutter/material.dart';

import '../app_theme.dart';

class NoticeDialog extends StatelessWidget {
  const NoticeDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = '确定',
    this.onConfirm,
  });

  final String title;
  final String content;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: ExampleTheme.surface.withAlpha(250),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: ExampleTheme.primary.withAlpha(31)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          color: ExampleTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        content,
        style: textTheme.bodyMedium?.copyWith(
          color: ExampleTheme.textSecondary,
          height: 1.6,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
          style: TextButton.styleFrom(
            foregroundColor: ExampleTheme.primary,
            textStyle: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

extension NoticeDialogExtension on BuildContext {
  Future<void> showNoticeDialog({
    required String title,
    required String content,
    String confirmLabel = '确定',
    VoidCallback? onConfirm,
  }) {
    return showDialog<void>(
      context: this,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NoticeDialog(
          title: title,
          content: content,
          confirmLabel: confirmLabel,
          onConfirm: onConfirm,
        );
      },
    );
  }
}
