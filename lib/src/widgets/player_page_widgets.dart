import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'downlink_center_loading.dart';

class PlayerCommandButton extends StatelessWidget {
  const PlayerCommandButton({
    super.key,
    required this.onOpenCommands,
  });

  final VoidCallback onOpenCommands;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: ExampleTheme.primary,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(92, 28),
          side: const BorderSide(color: ExampleTheme.primary, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onOpenCommands,
        child: const Text(
          '发送命令',
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class PlayerLogUploadButton extends StatelessWidget {
  const PlayerLogUploadButton({
    super.key,
    required this.uploadingLogs,
    required this.onUploadLogs,
  });

  final bool uploadingLogs;
  final VoidCallback onUploadLogs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: ExampleTheme.primary,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          minimumSize: const Size(84, 28),
          side: const BorderSide(
            color: ExampleTheme.primary,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: uploadingLogs ? null : onUploadLogs,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (uploadingLogs) ...<Widget>[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ExampleTheme.primary.withAlpha(214),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              uploadingLogs ? '上传中' : '上传日志',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class DownlinkVideoStage extends StatelessWidget {
  const DownlinkVideoStage({
    super.key,
    required this.videoView,
    required this.showStageOverlay,
    required this.stageStatusLabel,
    required this.indicatorMode,
  });

  final Widget videoView;
  final bool showStageOverlay;
  final String stageStatusLabel;
  final DownlinkCenterIndicatorMode indicatorMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: ExampleTheme.videoBackground),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(child: videoView),
          if (showStageOverlay)
            Center(
              child: DownlinkCenterLoading(
                label: stageStatusLabel,
                mode: indicatorMode,
              ),
            ),
        ],
      ),
    );
  }
}

class DownlinkOverlayGradient extends StatelessWidget {
  const DownlinkOverlayGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withAlpha(117),
              Colors.transparent,
              Colors.black.withAlpha(153),
            ],
          ),
        ),
      ),
    );
  }
}

class DownlinkControlButton extends StatelessWidget {
  const DownlinkControlButton({
    super.key,
    required this.connecting,
    required this.playing,
    required this.onPressed,
  });

  final bool connecting;
  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: connecting ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        backgroundColor: playing ? Colors.redAccent.shade200 : ExampleTheme.primary,
      ),
      icon: connecting
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(
              playing ? Icons.stop_circle_outlined : Icons.play_circle_fill_rounded,
            ),
      label: Text(
        connecting ? '连接中' : (playing ? '停止播放' : '开始播放'),
      ),
    );
  }
}
