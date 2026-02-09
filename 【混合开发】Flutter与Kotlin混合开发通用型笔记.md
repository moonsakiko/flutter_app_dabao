# 📘 【混合开发】Flutter + Kotlin 原生协同作战手册
**—— 打造“高颜值 UI”与“高性能内核”的终极方案**

## 🧠 1. 核心架构哲学：大脑与皮肤

在混合开发中，必须明确分工，严禁逻辑混淆：

*   **Flutter (皮肤层)**：负责**“好看”**和**“交互”**。
    *   只做：界面渲染、动画、用户输入、权限申请弹窗、结果展示。
    *   不做：繁重的图像处理、复杂的 AI 推理、底层硬件调用。
*   **Kotlin (大脑层)**：负责“算力”**和**“系统能力”**。
    *   只做：OpenCV 图像操作、TFLite 模型推理、文件 I/O (MediaStore)、多线程计算等等功能。
    *   不做：任何 UI 绘制（除了 Toast 调试）。

**通信桥梁**：`MethodChannel`。Flutter 发指令（如“修这张图”），Kotlin 干活并返回结果（如“修好了，路径是...”）。

---

## 🛠️ 2. 通用代码模块 (Copy-Paste Vault)

以下模块经过实战验证，可直接迁移到任何同类项目。

### 🔌 模块 A：通信桥梁 (The Bridge)

这是打通任督二脉的关键。

**Flutter 端 (`lib/utils/native_bridge.dart`)**:
```dart
import 'package:flutter/services.dart';

class NativeBridge {
  // 定义唯一的通道名称，必须与 Kotlin 端一致
  static const _channel = MethodChannel('com.example.app/processor');

  /// 通用调用方法
  /// [method]: 方法名 (如 "processImage")
  /// [args]: 参数 (推荐使用 Map 传递复杂数据)
  static Future<dynamic> callNative(String method, [Map<String, dynamic>? args]) async {
    try {
      final result = await _channel.invokeMethod(method, args);
      return result;
    } on PlatformException catch (e) {
      // 统一错误处理，将原生错误转化为 Flutter 异常
      throw Exception("Native Call Error: ${e.message}");
    }
  }
}
```

**Kotlin 端 (`MainActivity.kt`)**:
```kotlin
// 在 configureFlutterEngine 中注册
private val CHANNEL = "com.example.app/processor"

override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
        // 使用协程切换到 IO 线程，防止卡死 UI
        CoroutineScope(Dispatchers.IO).launch {
            try {
                when (call.method) {
                    "processImage" -> {
                        // 1. 解析参数
                        val args = call.arguments as? Map<String, Any>
                        val path = args?.get("path") as? String
                        
                        // 2. 执行耗时逻辑 (调用你的业务函数)
                        val output = myHeavyTask(path)
                        
                        // 3. 返回结果 (切回主线程)
                        withContext(Dispatchers.Main) { result.success(output) }
                    }
                    else -> withContext(Dispatchers.Main) { result.notImplemented() }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { 
                    result.error("ERROR", e.message, null) 
                }
            }
        }
    }
}
```

---

### 💾 模块 B：稳如泰山的图片保存 (MediaStore)

**痛点**：Android 10+ 分区存储导致 `File().write` 经常失败。
**解法**：放弃文件流，通过系统媒体库托管。**此代码兼容所有 Android 版本。**

**Kotlin 端工具函数**:
```kotlin
import android.content.ContentValues
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream

// 将 Bitmap 保存到系统相册的指定文件夹
// folderName: 如 "MySuperApp"
fun saveBitmapToGallery(context: Context, bm: Bitmap, folderName: String, fileName: String): String {
    val relativePath = Environment.DIRECTORY_PICTURES + File.separator + folderName

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        // Android 10+ 方式
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1) // 写入中状态
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues) 
            ?: throw Exception("MediaStore insert failed")

        resolver.openOutputStream(uri).use { out ->
            if (out == null) throw Exception("Output stream null")
            bm.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }
        
        // 写入完成，解除挂起
        contentValues.clear()
        contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, contentValues, null, null)
        
        return "Saved via MediaStore"
    } else {
        // Android 9- 方式
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), folderName)
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, fileName)
        FileOutputStream(file).use { out ->
            bm.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }
        // 广播刷新相册
        MediaScannerConnection.scanFile(context, arrayOf(file.toString()), null, null)
        return file.absolutePath
    }
}
```

---

### ☁️ 模块 C：云端打包通用脚本 (尊重本地配置版)

这是解决“云端环境与本地代码冲突”的终极脚本。它允许你在本地随意修改 Kotlin 代码和 Manifest，云端打包时会自动保留你的修改，同时重建干净的构建环境。

**`.github/workflows/build.yml`**:
```yaml
# ... (前置配置：Checkout, Java, Flutter 环境) ...

      # ♻️ 核心策略：备份用户逻辑 -> 重建安卓骨架 -> 恢复用户逻辑
      # 作用：既利用了 flutter create 的标准化环境，又保留了你写的 Kotlin 核心代码
      - name: Recreate Android Project with User Logic
        run: |
          mkdir -p user_backup
          
          # 1. 备份核心文件 (根据你的项目包名路径修改这里!!)
          # ⚠️ 只要是你手动修改过的原生文件，都要在这里备份
          PKG_PATH="android/app/src/main/kotlin/com/example/myapp" 
          if [ -d "$PKG_PATH" ]; then
             cp -r "$PKG_PATH" user_backup/
          fi
          if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
             cp android/app/src/main/AndroidManifest.xml user_backup/
          fi

          # 2. 销毁并重建 (清除 Gradle 缓存污染)
          rm -rf android
          flutter create . --platforms android --project-name my_app

          # 3. 恢复文件
          TARGET_DIR="android/app/src/main/kotlin/com/example/myapp"
          rm -rf "$TARGET_DIR" #以此为准
          mkdir -p "$(dirname "$TARGET_DIR")"
          cp -r user_backup/$(basename "$PKG_PATH") "$(dirname "$TARGET_DIR")"
          
          if [ -f "user_backup/AndroidManifest.xml" ]; then
             cp user_backup/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
          fi

      # 💉 注入原生依赖 (OpenCV, TFLite 等)
      # 作用：避免每次都要手动改 build.gradle
      - name: Inject Native Dependencies
        run: |
          cat >> android/app/build.gradle <<EOF
          
          dependencies {
              // 在这里添加你需要的安卓原生库
              implementation "org.jetbrains.kotlin:kotlin-stdlib:1.9.0"
              implementation "com.quickbirdstudios:opencv:4.5.3.0" 
          }
          EOF
```

---

## 📝 3. 经验总结 (The Philosophy)

1.  **尊重原生**：不要试图用 Flutter 去做图像像素级处理。Dart 很慢，C++/Kotlin 很快。该放手时就放手。
2.  **云端洁癖**：本地环境千奇百怪，云端环境始终如一。遇到诡异构建报错，**优先信赖云端“销毁-重建”脚本**，而不是在本地死磕 Gradle 配置。
3.  **日志为王**：混合开发调试难。Kotlin 端要多写 `try-catch` 并返回详细错误信息（`e.message`），Flutter 端要把这些错误弹窗显示出来，而不是默默吞掉。
4.  **防呆设计**：用户永远会做你意想不到的操作（比如两张图选一样的）。在 UI 层就把这些低级错误拦截掉，别传给底层。

这份笔记是你未来开发 OCR、滤镜、视频剪辑等高性能 APP 的基石。保持“UI与逻辑分离”的思想，你将无往不利。
## 💣 4. 避坑指南 (Troubleshooting)
### 🔴 云端：构建失败
*   **现象**：`sed: can't read android/settings.gradle`
    *   **原因**：上传的代码不完整，脚本找不到文件。
    *   **对策**：使用“重建策略”，脚本里加入 `flutter create` 强制生成骨架。
*   **现象**：`AndroidManifest.xml parse error`
    *   **原因**：XML 语法错误（少个尖括号或引号）。
    *   **对策**：本地检查语法，或者让脚本直接 `cat > ...` 覆盖写入标准文件。
*   **现象**：`Could not find method implementation()`
    *   **原因**：Gradle 脚本修改位置错误，插到了 `dependencies` 外面。
    *   **对策**：不再用 `sed` 盲改，而是用 `cat` 全量重写 `build.gradle` 文件。

### **📁伪装浏览器与网络下载**

#### **1. 陷阱：短链重定向的“假死”**
*   **现象**：使用 `Dio` 或 `HttpClient` 请求 `mapp.api.weibo.cn` 等短链时，状态码返回 **200 OK**，但内容是一堆 HTML 代码，无法获取重定向后的真实 URL。
*   **原因**：现代网页不再单纯依赖 HTTP 301/302 状态码跳转，而是广泛使用 **JavaScript (window.location.href)** 进行客户端跳转。普通 HTTP 客户端无法执行 JS 代码，因此被困在“中间页”。
*   **对策**：**降维打击**。放弃纯 HTTP 追踪，直接引入 **WebView (浏览器内核)**。让浏览器去执行 JS，我们只需监听 URL 的变化即可捕获最终地址。

#### **2. 陷阱：安卓系统的“隐形杀手” (Headless/Invisible View)**
*   **现象**：代码逻辑完美，但在真机（特别是小米/华为等国产 ROM）上，`HeadlessInAppWebView` 或 `Opacity: 0.0` 的浏览器控件**永远无法初始化**，回调函数不执行，日志卡在“等待内核启动”。
*   **原因**：安卓系统极其激进的省电策略。渲染管线会自动剔除**不可见**（透明度为0、尺寸为0、不在屏幕可视区域）的视图，拒绝为其分配资源。
*   **对策**：**像素级伪装 (Pixel Deception)**。
    1.  **必须可见**：`Opacity` 设为 `0.01`（肉眼不可见，但在系统眼里是可见的）。
    2.  **必须占位**：尺寸设为 `1x1` 或 `10x10` 像素。
    3.  **必须在顶层**：使用 `Stack` 布局将其置于图层底部或角落，而不是 `IndexedStack` 的后台索引。

#### **3. 陷阱：403 Forbidden 防盗链**
*   **现象**：成功解析出图片的高清 URL，但在下载时报错 `403 Forbidden`。
*   **原因**：服务器开启了 **防盗链 (Hotlink Protection)** 检查。它发现请求头中的 `Referer` 是空的（或者不是来自自家域名），判定为非法盗链，拒绝服务。
*   **对策**：**伪造通行证**。在下载请求 (`Dio.download`) 的 Header 中，显式添加 `Referer: https://weibo.com/`，并伪装标准的 PC/手机 User-Agent。

#### **4. 陷阱：API 的“空城计” (Cookie 缺失)**
*   **现象**：拿到了正确的微博 ID，API 接口也通了，但返回的数据是空的，或者找不到图片。
*   **原因**：**身份隔离**。浏览器（WebView）访问时生成了访客 Cookie，但随后的 API 请求（Dio）是一个全新的、无 Cookie 的客户端。服务器视其为“陌生人”，对部分内容（如长微博、转发内容）进行了隐藏。
*   **对策**：**身份窃取 (Cookie Injection)**。
    1.  利用 `CookieManager` 从刚才访问过页面的 WebView 中提取 Cookie。
    2.  将提取到的 Cookie 字符串注入到 Dio API 请求的 Header 中。
    3.  实现**“浏览器访问 -> 窃取凭证 -> API 带着凭证请求”**的闭环。

#### **5. 陷阱：硬件加速的“开关”**
*   **现象**：WebView 始终无法加载，或者应用闪退/白屏。
*   **原因**：现代 WebView 高度依赖 GPU 渲染。如果 `AndroidManifest.xml` 中的 `<application>` 标签没有开启 `android:hardwareAccelerated="true"`，内核将无法启动。
*   **对策**：**配置强写入**。不要依赖构建工具的默认配置，在 CI/CD 脚本中显式写入包含硬件加速开关的 Manifest 文件。
#### **6、 智能故障转移 (Smart Failover)**

*   **💥 现象**：
    *   用浏览器解析太慢（几秒），用 API 解析快但不稳定（有些链接解不开）。
*   **✅ 解法**：
    *   **双保险策略**：
        1.  优先尝试 **正则+API** (极速模式)，0.1秒解决战斗。
        2.  如果失败（返回空/解析不了），**自动无缝切换**到 WebView (深度模式)，浏览器加载该链接，获取 Cookie，再次尝试下载。
    *   这能保证 90% 的情况极速响应，10% 的疑难杂症也能兜底成功。
---

**核心心法总结：**
> **“对于反爬虫机制，不要试图用代码去模拟浏览器的每一个行为（那样太累且易碎），而是直接在 APP 里养一个‘真实的浏览器’，利用它去开路，然后窃取它的成果（URL、Cookie）。”**


