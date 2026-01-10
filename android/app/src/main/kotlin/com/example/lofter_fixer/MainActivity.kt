package com.example.lofter_fixer // ⚠️如果你改了项目名，这里要对齐

import android.graphics.Bitmap
import android.graphics.BitmapFactory
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
import org.tensorflow.lite.support.image.ImageProcessor
import org.tensorflow.lite.support.image.TensorImage
import org.tensorflow.lite.support.image.ops.ResizeOp
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.lofter_fixer/processor"
    private var tflite: Interpreter? = null
    
    // YOLOv8 标准输入尺寸 (通常是 640)
    private val INPUT_SIZE = 640 

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化 OpenCV
        if (!OpenCVLoader.initDebug()) {
            println("❌ OpenCV Load Failed!")
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "processImages") {
                val tasks = call.argument<List<Map<String, String>>>("tasks") ?: listOf()
                val confThreshold = call.argument<Double>("confidence")?.toFloat() ?: 0.5f
                
                // 在后台线程执行，避免卡死 UI
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        loadModel() // 加载模型
                        var successCount = 0
                        
                        tasks.forEach { task ->
                            val wmPath = task["wm"]!!
                            val cleanPath = task["clean"]!!
                            if (processOneImage(wmPath, cleanPath, confThreshold)) {
                                successCount++
                            }
                        }
                        
                        // 返回结果给 Flutter
                        withContext(Dispatchers.Main) {
                            result.success(successCount)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("ERR", e.message, null)
                        }
                    } finally {
                        tflite?.close() // 释放内存
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun loadModel() {
        // 从 assets 加载模型
        val modelFile = FileUtil.loadMappedFile(this, "best_float16.tflite")
        val options = Interpreter.Options()
        tflite = Interpreter(modelFile, options)
    }

    private fun processOneImage(wmPath: String, cleanPath: String, confThreshold: Float): Boolean {
        try {
            // 1. 读取图片
            val wmBitmap = BitmapFactory.decodeFile(wmPath) ?: return false
            val cleanBitmap = BitmapFactory.decodeFile(cleanPath) ?: return false

            // 2. 预处理 (Resize for YOLO)
            val imageProcessor = ImageProcessor.Builder()
                .add(ResizeOp(INPUT_SIZE, INPUT_SIZE, ResizeOp.ResizeMethod.BILINEAR))
                .build()
            var tImage = TensorImage.fromBitmap(wmBitmap)
            tImage = imageProcessor.process(tImage)

            // 3. 推理 (Run Inference)
            // YOLOv8 输出通常是 [1, 5, 8400] (cx, cy, w, h, conf) 或者 [1, 84, 8400] (含分类)
            // 这里假设你的模型只有一个类 (Watermark)
            val outputShape = tflite!!.getOutputTensor(0).shape() // e.g. [1, 5, 8400]
            val outputBuffer = tflite!!.getOutputTensor(0).dataType() // FLOAT32
            
            // 准备输出容器
            val outputArray = Array(1) { Array(outputShape[1]) { FloatArray(outputShape[2]) } }
            // 注意：有些模型输出是 [1, 8400, 5]，如果报错需交换维度逻辑
            // 这里按常见 Ultralytics 导出格式处理
            
            tflite!!.run(tImage.buffer, outputArray)

            // 4. 解析结果 (NMS & Coordinate Mapping)
            // 简化逻辑：找到置信度最高的那个框 (假设每张图主要修复最明显的水印)
            val bestBox = parseYoloOutput(outputArray, confThreshold, wmBitmap.width, wmBitmap.height)

            if (bestBox != null) {
                // 5. OpenCV 修复 (核心步骤)
                repairWithOpenCV(wmBitmap, cleanBitmap, bestBox, wmPath)
                return true
            }
            return false

        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    // 解析 YOLO 输出
    private fun parseYoloOutput(output: Array<Array<FloatArray>>, confThresh: Float, imgW: Int, imgH: Int): Rect? {
        // output[0] is [dimensions, anchors] e.g., [5, 8400]
        // row 0: x_center, 1: y_center, 2: width, 3: height, 4: confidence
        val rows = output[0] 
        val numAnchors = rows[0].size // 8400
        
        var maxConf = -1f
        var bestIdx = -1

        for (i in 0 until numAnchors) {
            val conf = rows[4][i] // 第5行是置信度
            if (conf > confThresh && conf > maxConf) {
                maxConf = conf
                bestIdx = i
            }
        }

        if (bestIdx != -1) {
            val cx = rows[0][bestIdx]
            val cy = rows[1][bestIdx]
            val w = rows[2][bestIdx]
            val h = rows[3][bestIdx]

            // 还原到原图尺寸
            // YOLO 输入是 640x640，原图是 imgW x imgH
            val scaleX = imgW.toFloat() / INPUT_SIZE
            val scaleY = imgH.toFloat() / INPUT_SIZE
            // 简单的信箱模式缩放还原逻辑 (fit logic) -> 这里简化为直接拉伸，对于普通矩形水印通常足够
            // 如需更精确需实现 Letterbox 逆变换
            
            val finalX = ((cx - w / 2) * scaleX).toInt()
            val finalY = ((cy - h / 2) * scaleY).toInt()
            val finalW = (w * scaleX).toInt()
            val finalH = (h * scaleY).toInt()

            // 稍微扩大一点范围 (Padding)
            val paddingW = (finalW * 0.2).toInt()
            val paddingH = (finalH * 0.1).toInt()

            return Rect(
                (finalX - paddingW).coerceAtLeast(0),
                (finalY - paddingH).coerceAtLeast(0),
                (finalW + paddingW * 2).coerceAtMost(imgW),
                (finalH + paddingH * 2).coerceAtMost(imgH)
            )
        }
        return null
    }

    private fun repairWithOpenCV(wmBm: Bitmap, cleanBm: Bitmap, rect: Rect, originalPath: String) {
        // 1. 转换 Bitmap 到 OpenCV Mat
        val wmMat = Mat()
        val cleanMat = Mat()
        Utils.bitmapToMat(wmBm, wmMat)
        Utils.bitmapToMat(cleanBm, cleanMat)

        // 2. 确保尺寸一致
        Imgproc.resize(cleanMat, cleanMat, wmMat.size(), 0.0, 0.0, Imgproc.INTER_LANCZOS4)

        // 3. 提取无水印图的 Patch
        // 确保 Rect 不越界
        val safeRect = Rect(
            rect.x, rect.y,
            rect.width.coerceAtMost(wmMat.cols() - rect.x),
            rect.height.coerceAtMost(wmMat.rows() - rect.y)
        )
        
        if (safeRect.width <= 0 || safeRect.height <= 0) return

        val patch = cleanMat.submat(safeRect)

        // 4. 覆盖到有水印图上
        patch.copyTo(wmMat.submat(safeRect))

        // 5. 保存结果
        val resultBm = Bitmap.createBitmap(wmMat.cols(), wmMat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(wmMat, resultBm)

        saveBitmap(resultBm, originalPath)
    }

    private fun saveBitmap(bm: Bitmap, originalPath: String) {
        val originalFile = File(originalPath)
        // 保存到公共相册目录下的 LofterFixed 文件夹
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "LofterFixed")
        if (!dir.exists()) dir.mkdirs()
        
        val file = File(dir, "Fixed_${originalFile.name}")
        FileOutputStream(file).use { out ->
            bm.compress(Bitmap.CompressFormat.JPEG, 98, out)
        }
    }
}