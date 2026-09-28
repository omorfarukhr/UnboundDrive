package app.unbounddrive.unbounddrive

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.unbounddrive/video_thumbnail"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVideoThumbnail" -> {
                    val filePath = call.argument<String>("filePath")
                    val fileBytes = call.argument<ByteArray>("fileBytes")
                    Thread {
                        var tempFile: File? = null
                        val retriever = MediaMetadataRetriever()
                        try {
                            if (filePath != null && File(filePath).exists()) {
                                retriever.setDataSource(filePath)
                            } else if (fileBytes != null) {
                                tempFile = File.createTempFile("thumb_temp_", ".mp4", cacheDir)
                                FileOutputStream(tempFile).use { it.write(fileBytes) }
                                retriever.setDataSource(tempFile.absolutePath)
                            } else {
                                runOnUiThread { result.error("INVALID_ARGS", "filePath or fileBytes required", null) }
                                return@Thread
                            }

                            val bitmap = retriever.getFrameAtTime(1000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                ?: retriever.frameAtTime

                            if (bitmap != null) {
                                val stream = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                                val byteArray = stream.toByteArray()
                                runOnUiThread { result.success(byteArray) }
                            } else {
                                runOnUiThread { result.success(null) }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(null) }
                        } finally {
                            try {
                                retriever.release()
                            } catch (_: Exception) {}
                            tempFile?.delete()
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}
