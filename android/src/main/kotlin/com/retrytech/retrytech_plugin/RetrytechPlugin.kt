package com.retrytech.retrytech_plugin

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.util.Log
import androidx.core.net.toUri
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.StaticOverlaySettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultMuxer
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.retrytech.retrytech_plugin.filter.RgbFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.nio.ByteBuffer


/** RetrytechPlugin */
class RetrytechPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    var context: Activity? = null
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "retrytech_plugin"
        )
        channel.setMethodCallHandler(this)
    }

    @UnstableApi
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {

            "shareToInstagram" -> {
                Log.d("TAG", "onMethodCall: ${call.arguments}")
                shareToInstagram(call.arguments.toString(), result)
            }
//
//            "mergeAudioAndVideo" -> {
//                Log.d("TAG", "onMethodCall: ${call.arguments}")
//                mergeAudio(call.arguments as Map<String, String>, result)
//            }
            "applyFilterAndAudioToVideo" -> {
                Log.d("TAG", "onMethodCall: ${call.arguments}")
                applyFilterAndAudioToVideo(call.arguments as Map<String, String>, result)
            }

            "addWaterMarkInVideo" -> {
                Log.d("TAG", "onMethodCall: ${call.arguments}")
                addWatermarkToVideo(call.arguments as Map<String, String>, result)
            }

            "extractAudio" -> {
                Log.d("TAG", "onMethodCall: ${call.arguments}")
                extractAudio(call.arguments as Map<String, String>, result)
            }


            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        context = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    }

    override fun onDetachedFromActivity() {
    }

    fun shareToInstagram(url: String, result: Result) {

        val shareIntent = Intent(Intent.ACTION_SEND)
        shareIntent.type = "text/plain"
        shareIntent.putExtra(Intent.EXTRA_TEXT, url)
        val pm = context!!.packageManager

        pm.queryIntentActivities(shareIntent, 0)
        shareIntent.setPackage("com.instagram.android")
        shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
        context!!.startActivity(shareIntent)

        try {
            Log.d("TAG", "onMethodCall: Sucess $shareIntent")
            result.success(true)
        } catch (e: Exception) {
            Log.e("TAG", "onMethodCall: Failed $shareIntent $e")
            result.success(false)
        }
    }

    @UnstableApi
    fun addWatermarkToVideo(arguments: Map<String, String>, result: Result) {
        try {
            val inputPath = arguments["input_path"]
            val thumbnailPath = arguments["thumbnail_path"]
            val outputPath = arguments["output_path"]
            val username = arguments["username"]

            if (inputPath.isNullOrEmpty() || outputPath.isNullOrEmpty()) {
                result.success(false)
                Log.e("addWatermark", "Missing input or output path.")
                return
            }

            val inputUri = inputPath.toUri()
            val outputUri = outputPath.toUri()
            val bitmap = if (!thumbnailPath.isNullOrEmpty()) {
                BitmapFactory.decodeFile(thumbnailPath)
            } else null

            if (bitmap == null) {
                result.success(false)
                Log.e("addWatermark", "Failed to decode thumbnail bitmap.")
                return
            }

            // Get video resolution
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(inputPath)
            val videoWidth =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    ?.toIntOrNull() ?: 0
            val videoHeight =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    ?.toIntOrNull() ?: 0
            retriever.release()

            if (videoWidth == 0 || videoHeight == 0) {
                result.success(false)
                Log.e("addWatermark", "Could not retrieve video dimensions.")
                return
            }

            Log.d("addWatermark", "Video resolution: ${videoWidth}x${videoHeight}")

            // Scale factors based on target width in pixels
            // Use percentage-based scaling for consistency across all resolutions

            val imageScaleFactor =
                if (videoWidth > 1080) 1.5f else if (videoWidth > 480) 0.8f else .5f  // 10% of video width
            val verticalAnchor = -0.8f   // Same Y for both overlays

            val imageOverlay = BitmapOverlay.createStaticBitmapOverlay(
                bitmap,
                StaticOverlaySettings.Builder()
                    .setAlphaScale(1f)
                    .setScale(imageScaleFactor, imageScaleFactor)
                    .setBackgroundFrameAnchor(0.8f, verticalAnchor)
                    .build()
            )

//            val spannableUsername = SpannableString(username ?: "").apply {
//                setSpan(ForegroundColorSpan(Color.WHITE), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
//            }
//
//            val textOverlay = TextOverlay.createStaticTextOverlay(
//                spannableUsername,
//                StaticOverlaySettings.Builder()
//                    .setAlphaScale(1f)
//                    .setScale(textScaleFactor, textScaleFactor)
//                    .setBackgroundFrameAnchor(0.1f + imageScaleFactor + 0.02f, verticalAnchor)
//                    .build()
//            )


            val effects = Effects(
                listOf(),
                listOf(
                    OverlayEffect(listOf(imageOverlay)),
//                    OverlayEffect(listOf(textOverlay))
                )
            )

            val editedItem = EditedMediaItem.Builder(MediaItem.fromUri(inputUri))
                .setEffects(effects)
                .build()

            val sequence = EditedMediaItemSequence.Builder(listOf(editedItem)).build()
            val composition = Composition.Builder(listOf(sequence)).build()

            val transformer = Transformer.Builder(context!!)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        Log.d("addWatermark", "Transformation completed")
                        result.success(true)
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        Log.e("addWatermark", "Transformation failed: ${exportException.message}")
                        result.success(false)
                    }
                })
                .build()

            transformer.start(composition, outputUri.path!!)
            Log.d("addWatermark", "Transformation started")

        } catch (e: Exception) {
            Log.e("addWatermark", "Unexpected error: ${e.message}", e)
            result.success(false)
        }
    }

    @UnstableApi
    private fun extractAudio(arguments: Map<String, String>, result: Result) {
        val videoUri = arguments["input_path"]?.toUri()
        val outputUri = arguments["output_path"]?.toUri()

        try {
            val extractor = MediaExtractor()
            extractor.setDataSource(videoUri?.path ?: "")

            var audioTrackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    break
                }
            }

            if (audioTrackIndex == -1) {
                result.success(false)
                return
            }

            extractor.selectTrack(audioTrackIndex)

            val muxer =
                MediaMuxer(outputUri?.path ?: "", MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val format = extractor.getTrackFormat(audioTrackIndex)
            val muxerTrackIndex = muxer.addTrack(format)
            muxer.start()

            val bufferSize = 1024 * 1024
            val buffer = ByteBuffer.allocate(bufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(buffer, 0)

                if (bufferInfo.size < 0) break

                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                extractor.advance()
            }

            muxer.stop()
            muxer.release()
            extractor.release()

            result.success(true)
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(false)
        }
    }


    @UnstableApi
    private fun applyFilterAndAudioToVideo(arguments: Map<String, Any>, result: Result) {
        val videoUri = arguments["input_path"]?.toString()?.toUri()
        val audioUri = arguments["audio_path"]?.toString()?.toUri()
        val outputUri = arguments["output_path"]?.toString()?.toUri()
        val filterValues = arguments["filter_values"] as ArrayList<Float>?
        val shouldAddBothMusics = arguments["should_add_both_musics"] as Boolean
        val audioStartTimeInMs = arguments["audio_start_time_in_ms"] as Double?


        val videoItemBuilder = EditedMediaItem.Builder(MediaItem.fromUri(videoUri!!))
            .setRemoveAudio(!shouldAddBothMusics);

        if (filterValues != null && filterValues.isNotEmpty()) {
            val videoEffects = mutableListOf<Effect>()

            val rgbFilter = RgbFilter(filterValues.toFloatArray())
            videoEffects.add(rgbFilter)
            videoItemBuilder.setEffects(Effects(listOf(), videoEffects))
        }
        val videoItem = videoItemBuilder.build()

        val mediaItemSequences: ArrayList<EditedMediaItemSequence> = ArrayList()
        val videoSequence = EditedMediaItemSequence.Builder(listOf(videoItem))
            .build()
        mediaItemSequences.add(videoSequence)

        if (audioUri != null) {
            val videoDurationUs = getVideoDurationUs(videoUri)
            val clippedAudioMediaItem = MediaItem.Builder()
                .setUri(audioUri)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(audioStartTimeInMs?.toLong() ?: 0L)
                        .setEndPositionMs((audioStartTimeInMs?.toLong() ?: 0L) + videoDurationUs)
                        .build()
                )
                .build()
            val audioItem = EditedMediaItem.Builder(clippedAudioMediaItem)
                .build()
            val audioSequence = EditedMediaItemSequence.Builder(listOf(audioItem))
                .build()
            mediaItemSequences.add(audioSequence)
        }


        val composition = Composition.Builder(mediaItemSequences).build()

        val transformer = Transformer.Builder(context!!)
            .setMuxerFactory(DefaultMuxer.Factory())
            .addListener(object : Transformer.Listener {
                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException
                ) {
                    result.success(false)
                    Log.d("TAG", "onMethodCall: " + exportException.message)
                    super.onError(composition, exportResult, exportException)
                }

                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    super.onCompleted(composition, exportResult)
                    result.success(true)
//                    Toast.makeText(context, "Complete", Toast.LENGTH_SHORT).show()
                }
            })
            .build()

        transformer.start(composition, outputUri?.path!!)


    }

    @UnstableApi
    private fun getVideoDurationUs(videoUri: Uri): Long {
        val retriever = MediaMetadataRetriever()
        retriever.setDataSource(context, videoUri)
        val durationMs =
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
                ?: 0L
        retriever.release()
        Log.d("Dhruv", "Video duration: $durationMs ms")
        return durationMs
    }


}
