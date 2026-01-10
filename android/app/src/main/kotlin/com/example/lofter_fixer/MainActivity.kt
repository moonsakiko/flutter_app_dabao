package com.example.lofter_fixer

import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.Mat
import org.opencv.core.Rect
import org.opencv.imgproc.Imgproc
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.common.FileUtil
import org.tensorflow.lite.support.common.ops.NormalizeOp
import org.tensorflow.lite.support.image.ImageProcessor
import org.tensorflow.lite.support.image.TensorImage
import org.tensorflow.lite.support.image.ops.ResizeOp
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.lofter_fixer/processor"
    private var tflite: Interpreter? = null
    private val INPUT_SIZE = 640 

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        OpenCVLoader.initDebug()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "processImages") {
                val tasks = call.argument<List<Map<String, String>>>("tasks") ?: listOf()
                val confThreshold = call.argument<Double>("confidence")?.toFloat() ?: 0.5f
                
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        if (tflite == null) {
                            val modelFile = FileUtil.loadMappedFile(context, "best_float16.tflite")
                            tflite = Interpreter(modelFile)
                        }
                        
                        var successCount = 0
                        val debugLogs = StringBuilder()

                        tasks.forEach { task ->
                            val wmPath = task["wm"]!!
                            val cleanPath = task["clean"]!!
                            // 👇 获取详细的处理结果
                            val log = processOneImage(wmPath, cleanPath, confThreshold)
                            
                            if (log == "SUCCESS") {
                                successCount++
                            } else {
                                // 收集每一张图的失败原因
                                debugLogs.append("${File(wmPath).name} -> $log\n")
                            }
                        }
                        
                        withContext(Dispatchers.Main) {
                            if (successCount == 0 && tasks.isNotEmpty()) {
                                // ❌ 如果一张都没成，把日志吐出来
                                result.error("SAVE_FAILED", "处理失败详情:\n$debugLogs", null)
                            } else {
                                result.success(successCount)
                            }
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("ERR", "致命错误: ${e.message}", null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun processOneImage(wmPath: String, cleanPath: String, confThreshold: Float): String {
        try {
            val wmBitmap = BitmapFactory.decodeFile(wmPath) ?: return "原图读取失败"
            val cleanBitmap = BitmapFactory.decodeFile(cleanPath) ?: return "无水印图读取失败"

            // --- 核心识别逻辑 (不变) ---
            val imageProcessor = ImageProcessor.Builder()
                .add(ResizeOp(INPUT_SIZE, INPUT_SIZE, ResizeOp.ResizeMethod.BILINEAR))
                .add(NormalizeOp(0f, 255f))
                .build()
            var tImage = TensorImage.fromBitmap(wmBitmap)
            tImage = imageProcessor.process(tImage)

            val outputTensor = tflite!!.getOutputTensor(0)
            val outputShape = outputTensor.shape()
            val dim1 = outputShape[1]
            val dim2 = outputShape[2]
            val outputArray = Array(1) { Array(dim1) { FloatArray(dim2) } }
            tflite!!.run(tImage.buffer, outputArray)

            val bestBox = if (dim1 > dim2) {
                 parseOutputTransposed(outputArray[0], confThreshold, wmBitmap.width, wmBitmap.height)
            } else {
                 parseOutputStandard(outputArray[0], confThreshold, wmBitmap.width, wmBitmap.height)
            }

            if (bestBox != null) {
                // 👇 关键：尝试修复并保存，如果保存炸了，会捕获异常
                return repairAndSave(wmBitmap, cleanBitmap, bestBox, wmPath)
            } else {
                return "置信度过低"
            }
        } catch (e: Exception) {
            return "异常: ${e.message}"
        }
    }

    private fun repairAndSave(wmBm: Bitmap, cleanBm: Bitmap, rect: Rect, originalPath: String): String {
        try {
            val wmMat = Mat(); val cleanMat = Mat()
            Utils.bitmapToMat(wmBm, wmMat); Utils.bitmapToMat(cleanBm, cleanMat)
            Imgproc.resize(cleanMat, cleanMat, wmMat.size(), 0.0, 0.0, Imgproc.INTER_LANCZOS4)
            
            val safeRect = Rect(
                rect.x.coerceIn(0, wmMat.cols()), rect.y.coerceIn(0, wmMat.rows()),
                rect.width.coerceAtMost(wmMat.cols() - rect.x), rect.height.coerceAtMost(wmMat.rows() - rect.y)
            )

            if (safeRect.width <= 0 || safeRect.height <= 0) return "修复区域无效"

            val patch = cleanMat.submat(safeRect)
            patch.copyTo(wmMat.submat(safeRect))
            
            val resultBm = Bitmap.createBitmap(wmMat.cols(), wmMat.rows(), Bitmap.Config.ARGB_8888)
            Utils.matToBitmap(wmMat, resultBm)

            // 👇 这里是保存逻辑，如果失败会抛出异常
            saveBitmapToGallery(resultBm, originalPath)
            return "SUCCESS"
        } catch (e: Exception) {
            return "保存失败: ${e.message}"
        }
    }

    // --- 🛡️ 稳如老狗的保存逻辑 ---
    private fun saveBitmapToGallery(bm: Bitmap, originalPath: String) {
        val fileName = "Fixed_${File(originalPath).name}"
        var outputStream: OutputStream? = null
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ 使用 MediaStore
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/LofterFixed")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val resolver = context.contentResolver
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues) 
                    ?: throw Exception("MediaStore Insert Failed")
                
                outputStream = resolver.openOutputStream(uri)
                if (outputStream == null) throw Exception("MediaStore Stream Failed")
                
                bm.compress(Bitmap.CompressFormat.JPEG, 98, outputStream)
                outputStream.close()
                
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            } else {
                // Android 9 及以下 使用 File
                val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "LofterFixed")
                if (!dir.exists() && !dir.mkdirs()) {
                    throw Exception("无法创建文件夹")
                }
                val file = File(dir, fileName)
                outputStream = FileOutputStream(file)
                bm.compress(Bitmap.CompressFormat.JPEG, 98, outputStream)
                outputStream.close()
                
                // 广播刷新
                MediaScannerConnection.scanFile(context, arrayOf(file.toString()), arrayOf("image/jpeg"), null)
            }
        } catch (e: Exception) {
            outputStream?.close()
            // 🚨 抛出异常，让上层捕获，不要吞掉！
            throw e
        }
    }

    // (保留原本的解析辅助函数: parseOutputStandard, parseOutputTransposed, convertToRect 不变)
    private fun parseOutputStandard(rows: Array<FloatArray>, confThresh: Float, imgW: Int, imgH: Int): Rect? {
        val numAnchors = rows[0].size 
        var maxConf = 0f
        var bestIdx = -1
        for (i in 0 until numAnchors) {
            val conf = rows[4][i] 
            if (conf > maxConf) { maxConf = conf; bestIdx = i }
        }
        if (maxConf < confThresh) return null
        return convertToRect(rows[0][bestIdx], rows[1][bestIdx], rows[2][bestIdx], rows[3][bestIdx], imgW, imgH)
    }

    private fun parseOutputTransposed(rows: Array<FloatArray>, confThresh: Float, imgW: Int, imgH: Int): Rect? {
        var maxConf = 0f
        var bestIdx = -1
        for (i in rows.indices) {
            val conf = rows[i][4] 
            if (conf > maxConf) { maxConf = conf; bestIdx = i }
        }
        if (maxConf < confThresh) return null
        return convertToRect(rows[bestIdx][0], rows[bestIdx][1], rows[bestIdx][2], rows[bestIdx][3], imgW, imgH)
    }

    private fun convertToRect(cx: Float, cy: Float, w: Float, h: Float, imgW: Int, imgH: Int): Rect {
        val scaleX = imgW.toFloat() / INPUT_SIZE
        val scaleY = imgH.toFloat() / INPUT_SIZE
        val finalX = ((cx - w / 2) * scaleX).toInt()
        val finalY = ((cy - h / 2) * scaleY).toInt()
        val finalW = (w * scaleX).toInt()
        val finalH = (h * scaleY).toInt()
        val paddingW = (finalW * 0.2).toInt()
        val paddingH = (finalH * 0.1).toInt()
        return Rect(
            (finalX - paddingW).coerceAtLeast(0),
            (finalY - paddingH).coerceAtLeast(0),
            (finalW + paddingW * 2).coerceAtMost(imgW),
            (finalH + paddingH * 2).coerceAtMost(imgH)
        )
    }
}