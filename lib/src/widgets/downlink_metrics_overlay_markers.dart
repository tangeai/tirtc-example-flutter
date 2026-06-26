import 'downlink_metrics_overlay_model.dart';

extension DownlinkMetricsOverlayMarkerPayloads on DownlinkMetricsOverlayModel {
  Map<String, Object?> debugMarkerPayload({required int sessionGeneration}) {
    return <String, Object?>{
      'session_generation': sessionGeneration,
      'requested_decoder_preference': requestedDecoderPreference,
      'video_width': videoWidth,
      'video_height': videoHeight,
      'video_codec': videoCodec,
      'audio_codec': audioCodec,
      'audio_sample_rate_hz': audioSampleRate,
      'audio_channels': audioChannels,
      'resolved_decoder_backend': resolvedDecoderBackend,
      'display_video_size': displayVideoSize,
      'display_video_codec': displayVideoCodec,
      'display_audio_codec': displayAudioCodec,
      'display_video_decoder': displayVideoDecoder,
      'audio_input_bitrate_kbps': audioInputBitrateKbps,
      'audio_input_packet_rate': audioInputPacketRate,
      'audio_render_callback_rate': audioRenderCallbackRate,
      'audio_output_continuity_ratio': audioOutputContinuityRatio,
      'audio_output_stall_count': audioRecentStutterCount,
      'audio_output_stall_total_ms': audioRecentStutterTotalMs,
      'audio_output_stall_peak_ms': audioRecentStutterPeakMs,
      'audio_output_stall_ratio': audioRecentStutterRatio,
      'audio_output_health_ok': audioOutputHealthOk,
      'audio_rate_window_duration_ms': audioRateWindowDurationMs,
      'audio_local_latency_window_duration_ms': audioLatencyWindowDurationMs,
      'audio_local_latency_total_average_ms': audioLatencyTotalAverageMs,
      'audio_local_latency_buffer_average_ms': audioLatencyBufferAverageMs,
      'audio_local_latency_decode_or_ready_average_ms': audioLatencyDecodeReadyAverageMs,
      'audio_local_latency_output_average_ms': audioLatencyOutputAverageMs,
      'audio_local_latency_total_sample_count': audioLatencyTotalSampleCount,
      'audio_local_latency_buffer_sample_count': audioLatencyBufferSampleCount,
      'audio_local_latency_decode_or_ready_sample_count': audioLatencyDecodeReadySampleCount,
      'audio_local_latency_output_sample_count': audioLatencyOutputSampleCount,
      'audio_local_latency_total_unavailable_count': audioLatencyTotalUnavailableCount,
      'audio_local_latency_session_duration_ms': audioLatencySessionDurationMs,
      'audio_local_latency_session_total_average_ms': audioLatencySessionTotalAverageMs,
      'audio_local_latency_session_total_min_ms': audioLatencySessionTotalMinMs,
      'audio_local_latency_session_total_peak_ms': audioLatencySessionTotalPeakMs,
      'audio_local_latency_session_total_sample_count': audioLatencySessionTotalSampleCount,
      'audio_local_latency_session_total_unavailable_count': audioLatencySessionTotalUnavailableCount,
      'video_input_bitrate_kbps': videoInputBitrateKbps,
      'video_input_fps': videoInputFps,
      'video_decoded_fps': videoDecodedFps,
      'video_render_fps': videoRenderFps,
      'video_render_continuity_ratio': videoRenderContinuityRatio,
      'video_output_health_ok': videoOutputHealthOk,
      'video_rate_window_duration_ms': videoRateWindowDurationMs,
      'video_local_latency_window_duration_ms': videoLatencyWindowDurationMs,
      'video_local_latency_total_average_ms': videoLatencyTotalAverageMs,
      'video_local_latency_buffer_average_ms': videoLatencyBufferAverageMs,
      'video_local_latency_decode_or_ready_average_ms': videoLatencyDecodeReadyAverageMs,
      'video_local_latency_output_average_ms': videoLatencyOutputAverageMs,
      'video_local_latency_total_sample_count': videoLatencyTotalSampleCount,
      'video_local_latency_buffer_sample_count': videoLatencyBufferSampleCount,
      'video_local_latency_decode_or_ready_sample_count': videoLatencyDecodeReadySampleCount,
      'video_local_latency_output_sample_count': videoLatencyOutputSampleCount,
      'video_local_latency_total_unavailable_count': videoLatencyTotalUnavailableCount,
      'video_local_latency_session_duration_ms': videoLatencySessionDurationMs,
      'video_local_latency_session_total_average_ms': videoLatencySessionTotalAverageMs,
      'video_local_latency_session_total_min_ms': videoLatencySessionTotalMinMs,
      'video_local_latency_session_total_peak_ms': videoLatencySessionTotalPeakMs,
      'video_local_latency_session_total_sample_count': videoLatencySessionTotalSampleCount,
      'video_local_latency_session_total_unavailable_count': videoLatencySessionTotalUnavailableCount,
      'local_latency_ok': localLatencyReady,
      'period_summary_available': periodSummaryAvailable,
      'period_summary_required_rows': <String, Object?>{
        'stutter': stutterPeriodReady,
        'latency_stats': latencyPeriodReady,
      },
      'av_output_health_ok': avOutputHealthOk,
      'runtime_focus_log': 'logs/runtime-focus.log',
    };
  }

  Map<String, Object?> smokeDebugMarkerPayload({required int sessionGeneration}) {
    return <String, Object?>{
      'session_generation': sessionGeneration,
      'video_width': videoWidth,
      'video_height': videoHeight,
      'video_codec': videoCodec,
      'audio_codec': audioCodec,
      'resolved_decoder_backend': resolvedDecoderBackend,
      'runtime_focus_log': 'logs/runtime-focus.log',
    };
  }

  Map<String, Object?> smokeRenderWindowMarkerPayload({required int sessionGeneration}) {
    return <String, Object?>{
      'session_generation': sessionGeneration,
      'audio_input_bitrate_kbps': audioInputBitrateKbps,
      'audio_input_packet_rate': audioInputPacketRate,
      'audio_render_callback_rate': audioRenderCallbackRate,
      'audio_output_continuity_ratio': audioOutputContinuityRatio,
      'audio_output_stall_count': audioRecentStutterCount,
      'audio_output_stall_total_ms': audioRecentStutterTotalMs,
      'audio_output_stall_peak_ms': audioRecentStutterPeakMs,
      'audio_output_stall_ratio': audioRecentStutterRatio,
      'audio_output_health_ok': audioOutputHealthOk,
      'video_stutter_session_total_ms': sessionStutterTotalMs,
      'video_stutter_session_count': sessionStutterCount,
      'video_stutter_session_peak_ms': sessionStutterPeakMs,
      'video_stutter_session_ratio': sessionStutterRatio,
      'video_input_bitrate_kbps': videoInputBitrateKbps,
      'video_input_fps': videoInputFps,
      'video_render_fps': videoRenderFps,
      'video_render_continuity_ratio': videoRenderContinuityRatio,
      'video_output_health_ok': videoOutputHealthOk,
      'video_rate_window_duration_ms': videoRateWindowDurationMs,
      'audio_local_latency_window_duration_ms': audioLatencyWindowDurationMs,
      'audio_local_latency_total_average_ms': _averageOrNull(audioLatencyTotalAverageMs, audioLatencyTotalSampleCount),
      'audio_local_latency_buffer_average_ms': _averageOrNull(
        audioLatencyBufferAverageMs,
        audioLatencyBufferSampleCount,
      ),
      'audio_local_latency_decode_or_ready_average_ms': _averageOrNull(
        audioLatencyDecodeReadyAverageMs,
        audioLatencyDecodeReadySampleCount,
      ),
      'audio_local_latency_output_average_ms': _averageOrNull(
        audioLatencyOutputAverageMs,
        audioLatencyOutputSampleCount,
      ),
      'audio_local_latency_total_sample_count': audioLatencyTotalSampleCount,
      'audio_local_latency_buffer_sample_count': audioLatencyBufferSampleCount,
      'audio_local_latency_decode_or_ready_sample_count': audioLatencyDecodeReadySampleCount,
      'audio_local_latency_output_sample_count': audioLatencyOutputSampleCount,
      'audio_local_latency_total_unavailable_count': audioLatencyTotalUnavailableCount,
      'audio_local_latency_session_duration_ms': audioLatencySessionDurationMs,
      'audio_local_latency_session_total_average_ms': _averageOrNull(
        audioLatencySessionTotalAverageMs,
        audioLatencySessionTotalSampleCount,
      ),
      'audio_local_latency_session_total_min_ms': _averageOrNull(
        audioLatencySessionTotalMinMs,
        audioLatencySessionTotalSampleCount,
      ),
      'audio_local_latency_session_total_peak_ms': _averageOrNull(
        audioLatencySessionTotalPeakMs,
        audioLatencySessionTotalSampleCount,
      ),
      'audio_local_latency_session_total_sample_count': audioLatencySessionTotalSampleCount,
      'audio_local_latency_session_total_unavailable_count': audioLatencySessionTotalUnavailableCount,
      'video_local_latency_window_duration_ms': videoLatencyWindowDurationMs,
      'video_local_latency_total_average_ms': _averageOrNull(videoLatencyTotalAverageMs, videoLatencyTotalSampleCount),
      'video_local_latency_buffer_average_ms': _averageOrNull(
        videoLatencyBufferAverageMs,
        videoLatencyBufferSampleCount,
      ),
      'video_local_latency_decode_or_ready_average_ms': _averageOrNull(
        videoLatencyDecodeReadyAverageMs,
        videoLatencyDecodeReadySampleCount,
      ),
      'video_local_latency_output_average_ms': _averageOrNull(
        videoLatencyOutputAverageMs,
        videoLatencyOutputSampleCount,
      ),
      'video_local_latency_total_sample_count': videoLatencyTotalSampleCount,
      'video_local_latency_buffer_sample_count': videoLatencyBufferSampleCount,
      'video_local_latency_decode_or_ready_sample_count': videoLatencyDecodeReadySampleCount,
      'video_local_latency_output_sample_count': videoLatencyOutputSampleCount,
      'video_local_latency_total_unavailable_count': videoLatencyTotalUnavailableCount,
      'video_local_latency_session_duration_ms': videoLatencySessionDurationMs,
      'video_local_latency_session_total_average_ms': _averageOrNull(
        videoLatencySessionTotalAverageMs,
        videoLatencySessionTotalSampleCount,
      ),
      'video_local_latency_session_total_min_ms': _averageOrNull(
        videoLatencySessionTotalMinMs,
        videoLatencySessionTotalSampleCount,
      ),
      'video_local_latency_session_total_peak_ms': _averageOrNull(
        videoLatencySessionTotalPeakMs,
        videoLatencySessionTotalSampleCount,
      ),
      'video_local_latency_session_total_sample_count': videoLatencySessionTotalSampleCount,
      'video_local_latency_session_total_unavailable_count': videoLatencySessionTotalUnavailableCount,
      'local_latency_ok': localLatencyReady,
      'period_summary_available': periodSummaryAvailable,
      'period_summary_required_rows': <String, Object?>{
        'stutter': stutterPeriodReady,
        'latency_stats': latencyPeriodReady,
      },
      'av_output_health_ok': avOutputHealthOk,
      'runtime_focus_log': 'logs/runtime-focus.log',
    };
  }
}

int? _averageOrNull(int? averageMs, int? sampleCount) {
  if (sampleCount == null || sampleCount <= 0) {
    return null;
  }
  return averageMs;
}
