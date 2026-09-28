import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> generateVideoThumbnailPlatform(Uint8List videoBytes, String extension) async {
  try {
    final ext = extension.toLowerCase();
    String mime = 'video/mp4';
    if (ext == 'webm') {
      mime = 'video/webm';
    } else if (ext == 'ogg' || ext == 'ogv') {
      mime = 'video/ogg';
    }

    final blob = html.Blob([videoBytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final video = html.VideoElement()
      ..src = url
      ..muted = true
      ..autoplay = false;

    final completer = Completer<Uint8List?>();

    void cleanup() {
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    }

    video.onLoadedMetadata.listen((_) {
      // Seek slightly into the video to avoid black intro frames
      final duration = video.duration ?? 0;
      final target = duration > 1.0 ? 0.8 : (duration > 0.1 ? duration / 2 : 0.1);
      video.currentTime = target;
    });

    video.onSeeked.listen((_) {
      try {
        final w = video.videoWidth > 0 ? (video.videoWidth > 320 ? 320 : video.videoWidth) : 240;
        final h = video.videoHeight > 0 ? (video.videoHeight > 180 ? 180 : video.videoHeight) : 135;
        final canvas = html.CanvasElement(width: w, height: h);
        final ctx = canvas.context2D;
        ctx.drawImageScaled(video, 0, 0, w, h);
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.82);
        final base64Str = dataUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        cleanup();
        if (!completer.isCompleted) completer.complete(bytes);
      } catch (_) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    video.onError.listen((_) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });

    // Timeout safety
    Future.delayed(const Duration(seconds: 3), () {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });

    return await completer.future;
  } catch (_) {
    return null;
  }
}
