package com.example.lofter_fixer

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.os.Environment
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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.lofter_fixer/processor"
    private var tflite: Interpreter? = null
    private val INPUT_SIZE = 640 

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        if (!OpenCVLoader.initDebug()) println("❌ OpenCV Load Failed!")

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
                        
                        // 存储成功修复的图片路径
                        val successPaths = mutableListOf<String>()
                        val debugLogs = StringBuilder()

                        tasks.forEach { task ->
                            val wmPath = task["wm"]!!
                            val cleanPath = task["clean"]!!
                            
                            // 传入 tasks 列表处理
                            val (status, savedPath) = processOneImage(wmPath, cleanPath, confThreshold)
                            
                            if (status == "SUCCESS" && savedPath != null) {
                                successPaths.add(savedPath)
                            } else {
                                debugLogs.append("File: ${File(wmPath).name} -> $status\n")
                            }
                        }
                        
                        withContext(Dispatchers.Main) {
                            if (successPaths.isEmpty() && tasks.isNotEmpty()) {
                                result.error("NO_DETECTION", "未检测到水印或保存失败，调试信息：\n$debugLogs", null)
                            } else {
                                // ✅ 返回成功文件的路径列表
                                result.success(successPaths)
                            }
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("ERR", "系统错误: ${e.message}", null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // 返回 Pair(状态信息, 保存的路径?)
    private fun processOneImage(wmPath: String, cleanPath: String, confThreshold: Float): Pair<String, String?> {
        try {
            val wmBitmap = BitmapFactory.decodeFile(wmPath) ?: return Pair("无法读取图片", null)
            val cleanBitmap = BitmapFactory.decodeFile(cleanPath) ?: return Pair("无法读取原图", null)

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

            return if (bestBox != null) {
                val savedPath = repairWithOpenCV(wmBitmap, cleanBitmap, bestBox, wmPath)
                if (savedPath != null) Pair("SUCCESS", savedPath) else Pair("保存失败", null)
            } else {
                Pair("置信度过低", null)
            }

        } catch (e: Exception) {
            return Pair("异常: ${e.message}", null)
        }
    }

    private fun parseOutputStandard(rows: Array<FloatArray>, confThresh: Float, imgW: Int, imgH: Int): Rect? {
        val numAnchors = rows[0].size
        var maxConf = 0f
        var bestIdx = -1

        for (i in 0 until numAnchors) {
            val conf = rows[4][i]
            if (conf > maxConf) {
                maxConf = conf
                bestIdx = i
            }
        }
        if (maxConf < confThresh) return null
        return convertToRect(rows[0][bestIdx], rows[1][bestIdx], rows[2][bestIdx], rows[3][bestIdx], imgW, imgH)
    }

    private fun parseOutputTransposed(rows: Array<FloatArray>, confThresh: Float, imgW: Int, imgH: Int): Rect? {
        var maxConf = 0f
        var bestIdx = -1
        for (i in rows.indices) {
            val conf = rows[i][4] 
            if (conf > maxConf) {
                maxConf = conf
                bestIdx = i
            }
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

    // ⬇️ 修改保存逻辑：保存到 Downloads 并通知系统扫描
    private fun repairWithOpenCV(wmBm: Bitmap, cleanBm: Bitmap, rect: Rect, originalPath: String): String? {
        try {
            val wmMat = Mat()
            val cleanMat = Mat()
            Utils.bitmapToMat(wmBm, wmMat)
            Utils.bitmapToMat(cleanBm, cleanMat)

            Imgproc.resize(cleanMat, cleanMat, wmMat.size(), 0.0, 0.0, Imgproc.INTER_LANCZOS4)
            
            val safeRect = Rect(
                rect.x.coerceIn(0, wmMat.cols()),
                rect.y.coerceIn(0, wmMat.rows()),
                rect.width.coerceAtMost(wmMat.cols() - rect.x),
                rect.height.coerceAtMost(wmMat.rows() - rect.y)
            )

            if (safeRect.width > 0 && safeRect.height > 0) {
                val patch = cleanMat.submat(safeRect)
                patch.copyTo(wmMat.submat(safeRect))
                
                val resultBm = Bitmap.createBitmap(wmMat.cols(), wmMat.rows(), Bitmap.Config.ARGB_8888)
                Utils.matToBitmap(wmMat, resultBm)
                
                // 📂 保存到 Download 文件夹
                return saveBitmapToDownloads(resultBm, originalPath)
            }
            return null
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun saveBitmapToDownloads(bm: Bitmap, originalPath: String): String? {
        val originalFile = File(originalPath)
        // 使用 DIRECTORY_DOWNLOADS 更加稳妥
        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val targetDir = File(downloadDir, "LofterFixed")
        if (!targetDir.exists()) targetDir.mkdirs()
        
        val targetFile = File(targetDir, "Fixed_${originalFile.name}")
        
        try {
            FileOutputStream(targetFile).use { out ->
                bm.compress(Bitmap.CompressFormat.JPEG, 98, out)
            }
            
            // 📸 关键步骤：通知系统图库扫描该文件
            MediaScannerConnection.scanFile(this, arrayOf(targetFile.toString()), null, null)
            
            return targetFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
}