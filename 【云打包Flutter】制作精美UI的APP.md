## 🦋 【Flutter极速构建】Flutter + GitHub Actions 云打包指南

**适用场景**：你需要一个**高颜值、高性能、自带 Material Design 3 设计**的安卓 APP，且需要包含图片、GIF、自定义字体等媒体资源。
**原理**：利用 GitHub 的 Linux 服务器，配置 Flutter 环境，自动构建并生成 APK 安装包。相比 Kivy，Flutter 的 UI 渲染更现代化，且原生支持媒体资源管理。

---

### 🚀 核心四步走

你需要上传以下核心文件到 GitHub 仓库。

#### 📂 文件结构 (推荐)
Flutter 的文件结构比 Python 稍微严格一点，请保持以下结构：
```text
/ (仓库根目录，无大写字母)
├── pubspec.yaml             (相当于 buildozer.spec，最关键的配置文件)
├── lib/
│   └── main.dart            (你的各种代码)
├── assets/                  (资源文件夹，必须叫这个名字)
│   ├── images/
│   │   ├── icon.png         (图标/图片)
│   │   └── cat.gif          (动图)
│   └── fonts/
│       └── myfont.ttf       (字体文件)
└── .github/workflows/build.yml  (告诉 GitHub 怎么干活)
```

---
#### 第零步:仓库名不能用大写字母
Flutter（Dart语言）有一条死规定：**项目名称（Package Name）必须全小写，单词之间用下划线隔开**（学名叫蛇形命名法 snake_case）。
而读取项目名称会把仓库名也同样读取，所以仓库名也不能有大写字母。
#### 第一步：配置环境 (`pubspec.yaml`)
**这是 Flutter 的心脏。** 所有的库、图片、字体都在这里注册。
请在仓库根目录新建 `pubspec.yaml`，
```
pubspec.yaml
```

粘贴以下内容（**注意缩进必须严格对齐！**）或者让AI编写专门对应的内容：

```yaml
name: my_flutter_app
description: A new Flutter project.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  # 👇 在这里添加你要用的库
  cupertino_icons: ^1.0.2
  shared_preferences: ^2.2.0  # 示例：本地存储库

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

# 👇 ❗❗❗ 资源注册区 (缩进非常重要) ❗❗❗
flutter:
  uses-material-design: true

  # 1. 注册图片/GIF (写到文件夹级别即可包含下面所有文件)
  assets:
    - assets/images/

  # 2. 注册字体
  fonts:
    - family: MyFont  # 代码里引用的名字
      fonts:
        - asset: assets/fonts/myfont.ttf
```

---

#### 第二步：准备代码 (`lib/main.dart`)
在仓库里新建文件夹 `lib`，并在里面新建 `main.dart`。
```
lib/main.dart
```

这是一个包含了**图片加载、字体使用、交互逻辑**的标准模版：

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Cloud App',
      theme: ThemeData(
        useMaterial3: true, // 开启新版设计
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: 'MyFont', // 👑 全局应用自定义字体
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("资源测试")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🖼️ 加载本地图片
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
                image: const DecorationImage(
                  image: AssetImage('assets/images/icon.png'), // 引用路径
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 🔡 使用自定义字体
            const Text(
              "Hello Flutter!",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("这是自定义字体效果"),
          ],
        ),
      ),
    );
  }
}
```

---

#### 第三步：上传资源 (`assets/`)

1.  在根目录新建文件夹命名为 `assets`。
2.  在 `assets` 下新建 `images` 文件夹，放入你的图片（如 `icon.png`, `loading.gif`）。
3.  在 `assets` 下新建 `fonts` 文件夹，放入你的字体文件（如 `myfont.ttf`）。
    *   *注意：文件名必须和 `pubspec.yaml` 里写的一模一样，区分大小写！推荐直接用myfont.tff*

---

#### 第四步：配置打包流程 (`.github/workflows/build.yml`)
如果是AI工作区编写代码，开头则设置成更新代码即运行一次工作流。

新建 build.yml文件。
```
.github/workflows/build.yml
```
这段脚本有一个**黑科技**：它会自动检测你是否上传了 Android 工程文件。如果你只上传了 `main.dart` 和 `pubspec.yaml`，**它会自动帮你生成 Android 工程骨架**，实现真正的“代码即应用”。
并且包含了“设定中文名称”，“自定义图标”，“恢复特有密钥”，“极值体积打包”等功能。
你可以以此为蓝本作参考。顺便一提，如果是AI工作区编写代码可以设置成更新代码即运行一次工作流。
```
name: Flutter Build Signed Release
on:
  workflow_dispatch:

# 📝 代码头部区域定义APP中文名，方便在这里修改你的 APP 名称
env:
  APP_NAME: "你的APP中文名"

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'

      # 1. 生成工程
      - name: Create Android Project
        run: |
          if [ ! -d "android" ]; then
            # 注意：内部项目名 my_diary_app 必须是英文，不要改这里
            flutter create . --platforms android --project-name my_diary_app
          fi

      # 2. 🏷️ 强制修改中文名 (最稳妥的方法)
      - name: Change App Name
        run: |
          # 修改 Android 清单文件中的 label 属性
          sed -i 's/android:label="[^"]*"/android:label="${{ env.APP_NAME }}"/g' android/app/src/main/AndroidManifest.xml
          echo "✅ App name changed to: ${{ env.APP_NAME }}"

      # 3. 修复环境
      - name: Fix Android Environment
        run: |
          sed -i 's/id "org.jetbrains.kotlin.android" version ".*"/id "org.jetbrains.kotlin.android" version "1.9.0"/g' android/settings.gradle
          sed -i "s/ext.kotlin_version = .*/ext.kotlin_version = '1.9.0'/g" android/build.gradle
          sed -i 's/minSdkVersion.*/minSdkVersion 21/g' android/app/build.gradle

      # 4. 生成资源 (只生成图标，不生成名字了，因为名字上面改过了)
      - name: Install Dependencies & Assets
        run: |
          flutter pub get
          echo "🎨 Generating App Icon..."
          dart run flutter_launcher_icons

      # 5. 恢复密钥
      - name: Restore Keystore from Secrets
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > upload-keystore.jks
          echo "storePassword=${{ secrets.KEY_PASSWORD }}" > android/key.properties
          echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/key.properties
          echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> android/key.properties
          echo "storeFile=../../upload-keystore.jks" >> android/key.properties

      # 6. 打包
      - name: Build APK
        run: flutter build apk --release --target-platform android-arm64

      # 7. 上传
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: diary-app-release
          path: build/app/outputs/flutter-apk/app-release.apk
```

### 🛠️ 提问 (FAQ)
#### Q1: 中文乱码吗？
**A:** Flutter 默认支持中文，**不会乱码**。
但如果你想用好看的艺术字体，就需要按照第三步上传 `.ttf` 文件。如果不上传，默认会使用安卓系统的默认中文字体（也挺好看的）。

---

## 🎨 【附录】Flutter 自定义图标与启动图配置指南

**核心目标**：在 GitHub Actions 云打包流程中，自动替换默认的 Flutter 图标和启动白屏，打造专业级 APP 体验。

---
### 🛠️ 1.准备工作

#### 1.1 准备图片
在仓库根目录建立 `assets/images/` 文件夹，上传以下两张图：
1.  **图标 (`icon.png`)**：
    *   尺寸：**1024x1024** px。
    *   样式：正方形，**不要**自己切圆角（系统会自动切）。
2.  **启动图 Logo (`splash.png`)**：
    *   尺寸：**512x512** px (或 500x500)。
    *   样式：透明背景的 PNG Logo，主体居中。

#### 1.2 修改配置文件 (`pubspec.yaml`)

将以下配置追加到 `pubspec.yaml` 末尾。
**注意**：我们将 `ios` 设为 `false`，因为我们只构建 Android 包，避免找不到 iOS 文件夹导致报错。

```yaml
dev_dependencies:
  # 👇 引入这两个自动化库
  flutter_launcher_icons: ^0.13.1
  flutter_native_splash: ^2.3.1

# --- 1. 图标配置 ---
flutter_launcher_icons:
  android: "launcher_icon"
  ios: false     # ❗关键：只打安卓包时，必须关掉 iOS，否则报错
  image_path: "assets/images/icon.png"
  min_sdk_android: 21 # 适配 Android 5.0+

# --- 2. 启动图配置 (省体积版) ---
flutter_native_splash:
  # 背景色 (推荐米色或白色，不占体积)
  color: "#F5F5F5"
  
  # 中间的 Logo (体积小)
  image: "assets/images/splash.png"
  
  # ❌ 严禁使用 background_image (全屏图)，会导致体积翻倍！
  # background_image: "assets/images/big_wallpaper.png"

  # Android 12+ 适配 (保持一致)
  android_12:
    color: "#F5F5F5"
    image: "assets/images/splash.png"
```

---

### 🤖 2. 自动化流程 (`build.yml`)

在 GitHub Actions 的 YAML 文件中，我们需要在 **“安装依赖”之后**，**“打包 APK”之前**，插入生成资源的命令。

**代码片段：**

```yaml
      # ... (前序步骤：Install Dependencies) ...
      - name: Install Dependencies
        run: flutter pub get

      # 👇👇👇 【插入这一步】自动生成图标和启动页 👇👇👇
      - name: Generate Assets (Icons & Splash)
        run: |
          echo "🎨 Generating App Icon..."
          dart run flutter_launcher_icons
          
          echo "🌊 Generating Splash Screen..."
          dart run flutter_native_splash:create

      # ... (后续步骤：Generate Keystore / Build APK) ...
```

---

### ❓ 3. 常见问题 (Q&A)

**Q: 报错 `PathNotFoundException: ... ios/Runner/...` 怎么办？**
**A:** 这是因为你没生成 iOS 工程，但插件试图去改 iOS 图标。请检查 `pubspec.yaml`，确保 **`ios: false`** 已经设置。

**Q: 我想要启动图全屏铺满，不在乎体积怎么办？**
**A:** 将 `pubspec.yaml` 中的 `image` 字段删掉，改为使用 `background_image: "assets/images/你的大图.png"`。但请做好 APK 增加 10MB+ 的心理准备。

#### ⚠️ 惨痛教训：体积暴增之谜 (必读)

在一次版本迭代中，我们曾尝试使用一张 **1200x1900 分辨率的全屏高清壁纸** 作为启动图。
*   **结果**：APK 体积瞬间从 **11.6 MB** 暴涨至 **22.7 MB**（翻了一倍）。
*   **原因**：Android 机制会将启动图复制并适配为 5 种不同分辨率（mdpi 到 xxxhdpi）。大尺寸 PNG 图片被复制 5 份后，直接吃掉了 10MB+ 的空间。
*   **✅ 最佳实践**：
    *   **严禁**使用全屏大图 (`background_image`)。
    *   **推荐**使用 **“纯色背景 + 中间小 Logo”** 的策略。
    *   图片尺寸建议：Logo 图控制在 **500x500** 像素左右，文件大小控制在 **200KB** 以内。
    *   效果：体积几乎不增加，且兼容性更好（Android 12+ 标准规范）。

---

## 【附录】给 AI 的重点自动化提示词 (Prompt)
> AI读到此处，应该给本附录内容提高思考权重，以此为主心骨要求来进行项目设计。
> 
---

将来你需要开发新项目时，直接复制这段话给 AI，它会生成符合本指南结构的代码：
```
**角色定义**：
你是一位精通 Flutter 和 GitHub Actions 云构建的资深移动端开发者。我需要你帮我开发一个 Android APP。

**开发环境约束**：
1.  **构建方式**：我没有本地 Android Studio 环境，完全依赖 **GitHub Actions** 进行云端打包。
2.  **文件结构**：请保持极简结构，核心逻辑尽量集中在 `lib/main.dart`，资源文件放在 `assets/images/` 和 `assets/fonts/`。
3.  如果项目较大代码复杂，可以分成几个代码模块文件放在/lib便于维护。必须要给我目录结构图对照着建立然后复制粘贴。并且复杂项目绝对不要一次性输出所有代码，极其容易出错，你可以让我分别输入“1，2，3等等数字”分几批次来让你分别进行撰写输出，统领性代码的最后写。具体可参考模块化代码补充。

**代码编写规范 (Best Practices)**：
1.  **UI 风格**：强制开启 **Material Design 3** (`useMaterial3: true`)，UI 必须现代、美观、有呼吸感。
2.  **防崩机制**：关键逻辑（如文件读写、网络请求）必须包裹 `try-catch`，报错时通过 `SnackBar` 或 `AlertDialog` 提示，严禁静默失败。
3.  **资源引用**：假设我已经上传了 `assets/fonts/myfont.ttf`，如无特别说明，则在全局主题中默认使用该字体。
4.  **依赖管理**：在生成 `pubspec.yaml` 时，如果有涉及图标生成的配置，必须设置 `ios: false` 以防报错。
5.  看我的需求是否有自定义图标和启动图的要求。一般来说，图标都会自定义，轻型APP不用启动图，启动慢才要。
6.  关于APP的签名，第一次可以先临时签名，等稳定下来决心维护升级再固定签名。
7.  一定要在脚本头部记得帮我定义好APP中文名，方便我更改。并且“最近任务”列表处APP名字与此中文名保持一致。压缩包和安装包名可以是英文名。
8.  只要是需要更改和填写的文件代码，都输出完整的全部代码，方便我直接复制粘贴。
9.  为了方便我使用一键生成文件目录脚本，请务必保证在每个代码块前的代码文件相对路径完整，而且每个文件路径添加标记“FILE:”，形成`FILE: 路径/文件名.后缀`。

**打包脚本规范 (关键！必须严格遵守)**：
在生成 `.github/workflows/build.yml` 时，必须包含以下“黄金配置”以解决环境冲突并实现极致压缩：
1.  **环境修复**：必须包含 `sed` 命令强制修改 `settings.gradle` 和 `build.gradle` 中的 Kotlin 版本为 **1.9.0**，并将 MinSDK 修正为 **21**。
2.  **密钥生成**：必须包含 `keytool` 命令现场生成 `upload-keystore.jks` 和 `key.properties`。
3.  **极致压缩**：构建命令必须是 `flutter build apk --release --target-platform android-arm64`（只打 Release 包且只保留 Arm64 架构）。

---
**我的本次需求是：**
[在此处输入你想做的APP功能与各种需求]
```
### 📂 模块化代码补充：复杂的 APP 该怎么分文件？
⚠️重要补充:⚠️
千万不要一次性输出所有代码，及其容易出错，你可以让我分别输入“1，2，3等等数字”分几批来分别让你进行撰写输出，统领性代码的最后写。
并且，为了方便我使用一键生成文件目录脚本，请务必保证在每个代码块前的代码文件相对路径完整，而且每个文件路径添加标记“FILE:”，形成`FILE: 路径/文件名.后缀`。

---
当你的代码超过 500 行时，就该拆分了。Flutter 项目有非常标准的**“分层架构”**。

如果你想做一个长期维护的 APP，建议让 AI 按照下面这个结构给你生成代码。

#### 推荐的目录结构(以日记APP为例)

```text
lib/
├── main.dart           (入口文件：只负责启动 APP 和全局配置)
├── models/             (数据模型：定义日记长什么样)
│   ├── diary_entry.dart
│   └── future_letter.dart
├── screens/            (页面：一个个完整的屏幕)
│   ├── home_page.dart      (首页)
│   ├── detail_page.dart    (写日记页)
│   └── letter_box_page.dart(信箱页)
├── widgets/            (组件：可复用的小零件)
│   ├── timeline_item.dart  (那个漂亮的时间轴条目)
│   └── modern_card.dart    (通用的卡片样式)
└── utils/              (工具：存数据、处理时间的逻辑)
    ├── storage_manager.dart (专门负责 SharedPreferences)
    └── date_formatter.dart  (专门负责把日期变好看)
```

#### 这种分法的好处：
1.  **AI 不会晕**：你可以一次只把一个文件发给 AI 让它改。比如“帮我优化 `timeline_item.dart` 的样式”，AI 就不需要读取其他几千行无关代码，反应更快，错误更少。
2.  **改哪里很清楚**：想改首页？去 `screens/home_page.dart`。想改数据保存逻辑？去 `utils`。
3.  **方便复用**：`widgets` 里的组件可以在任何页面用。

---

### 🤖 既然分了文件，怎么让 AI 写代码？

以前是“给我生成一个完整的 main.dart”。
现在你需要学会 **“模块化 Prompt”**。

#### 第一步：让 AI 设计结构(以日记APP为例)
> “我要做一个复杂的日记 APP。请帮我设计一个合理的 `lib/` 目录结构，并告诉我每个文件应该放什么代码。”

#### 第二步：逐个生成文件 (One by One)
不要让它一次吐出所有代码（它会截断）。你要分批次要。

> **指令 1**：
> “好，首先请给我 **`lib/models/diary_entry.dart`** 的代码，包含 `toJson` 和 `fromJson`。”
>
> **指令 2**：
> “接下来，请给我 **`lib/utils/storage_manager.dart`** 的代码，它依赖上面的 Model，负责封装 SharedPreferences 的增删改查。”
>
> **指令 3**：
> “现在，请写 **`lib/widgets/timeline_item.dart`**，它需要引入 Model，只负责 UI 展示。”

#### 第三步：最后组装
> “最后，请给我 **`lib/main.dart`**，把上面所有的页面串联起来，设置好路由。”

---

## 【附录】📉 极限瘦身与 Release 云打包指南

**适用场景**：
你的 APP 开发完毕，准备正式使用。你需要一个**体积极小、启动极快、没有调试卡顿**的正式安装包（APK），并且要解决 `share_plus` 等现代插件带来的环境报错。

**核心成果**：
*   **体积**：从 Debug 版的 ~130MB 降至 Release 版的 **~11MB**。
*   **性能**：开启 AOT 编译（机器码），启动速度提升 50% 以上。
*   **兼容性**：自动修复 Kotlin 版本冲突和 MinSDK 限制。

---

### 1. 核心原理：为什么能压到这么小？

1.  **Release 模式 (AOT)**：Debug 包里塞了一个巨大的 Dart 虚拟机（JIT）和调试代码。Release 模式会把 Dart 代码直接编译成机器码，丢掉虚拟机，并执行 **Tree Shaking**（摇树优化），自动删掉没用到的库代码。
2.  **架构过滤 (Arm64)**：默认打包会包含 `arm64` (新手机), `armv7` (古董机), `x86` (模拟器) 三套内核。我们指定 `--target-platform android-arm64`，只保留现代手机架构。
3.  **云端签名 (Keystore)**：Release 包必须签名才能安装。我们在 GitHub Actions 里**现场生成**一个临时签名证书，骗过编译器，生成可安装的正式包。

---

### 2. 完整打包脚本参考 (`.github/workflows/build.yml`)

这是经过多次迭代验证的**脚本配置**。它内置了**环境自动修复**和**密钥自动生成**。
**`build.yml`：**

```yaml
name: Flutter Build Final Release
on:
  workflow_dispatch: # 手动触发

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      # 1. 配置基础环境
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'

      # 2. 生成安卓工程骨架
      - name: Create Android Project
        run: |
          if [ ! -d "android" ]; then
            # 强制指定项目名，防止文件夹大小写导致报错
            flutter create . --platforms android --project-name my_diary_app
          fi

      # 3. 💉【关键步骤】环境自动修复
      # 解决 share_plus 等新插件导致的 Kotlin 版本冲突和 MinSDK 报错
      - name: Fix Android Environment
        run: |
          echo "🔧 Fixing Kotlin Version to 1.9.0..."
          # 修改 settings.gradle 中的插件版本
          sed -i 's/id "org.jetbrains.kotlin.android" version ".*"/id "org.jetbrains.kotlin.android" version "1.9.0"/g' android/settings.gradle
          # 保险起见，尝试修改 build.gradle
          sed -i "s/ext.kotlin_version = .*/ext.kotlin_version = '1.9.0'/g" android/build.gradle
          
          echo "🔧 Fixing MinSdkVersion to 21..."
          # 修改 app/build.gradle 中的最低支持版本
          sed -i 's/minSdkVersion.*/minSdkVersion 21/g' android/app/build.gradle

      - name: Install Dependencies
        run: flutter pub get

      # 4. 🔑【关键步骤】云端生成签名
      # Release 包必须签名。这里我们在服务器上现场造一个证书。
      - name: Generate Keystore
        run: |
          # 1. 生成 upload-keystore.jks 文件
          keytool -genkey -v -keystore upload-keystore.jks \
            -keyalg RSA -keysize 2048 -validity 10000 \
            -alias upload -dname "CN=Android, OU=Android, O=Android, L=Android, S=Android, C=US" \
            -storepass android -keypass android
          
          # 2. 生成 key.properties 配置文件
          # Flutter 编译时会自动读取这个文件来寻找密钥
          echo "storePassword=android" > android/key.properties
          echo "keyPassword=android" >> android/key.properties
          echo "keyAlias=upload" >> android/key.properties
          echo "storeFile=../../upload-keystore.jks" >> android/key.properties

      # 5. ✨【极限瘦身】打包 Release + ARM64
      # --release: 开启混淆和压缩
      # --target-platform: 只保留目前99%手机通用的 arm64 架构
      - name: Build APK
        run: flutter build apk --release --target-platform android-arm64

      # 6. 上传最终产物
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: diary-app-release-final
          path: build/app/outputs/flutter-apk/app-release.apk
```

---

### 3. 提问解答 (FAQ)
#### **Q1:为什么Debug模式显示红屏报错，而Release只是白屏/无反应？**

1.  **红屏 (Red Screen of Death)**：这是 **Debug 模式** 下特有的。Flutter 怕你不知道哪里错了，特意把错误堆栈画在屏幕上，方便你调试。
2.  **白屏/灰屏 (Grey Screen)**：这是 **Release 模式**。为了不让普通用户看到可怕的红色代码，Flutter 在正式版中会屏蔽红屏，导致出错的组件直接不渲染（变成灰色或白色），或者点击按钮没有任何反应（静默失败）。
所以测试代码功能时也可以用Debug模式进行排查。
#### Q2: 为什么还需要修复 Kotlin 版本？
**A:** 
*   **现象**：打包时报错 `Module was compiled with an incompatible version of Kotlin`。
*   **原因**：GitHub Actions 自动生成的安卓骨架比较旧（Kotlin 1.7），但你引入的插件（如 `share_plus`）是最新的（Kotlin 1.9）。
*   **对策**：脚本中的 `Fix Android Environment` 步骤会自动把项目强行升级到 1.9.0，一劳永逸。

### 4. 总结

Flutter 的 GitHub 云打包其实就两句话：
1.  **Debug 模式**用来测试逻辑，体积大（100MB+），不需要签名。
2.  **Release 模式**用来日常使用，体积小（10MB+），**必须配合 Keystore 生成脚本**使用。

### 5.原始Debug版本备份
```yaml
name: Flutter Build APK
on:
  workflow_dispatch: # 手动触发

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      # 1. 配置 Java 环境
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin'
          java-version: '17'

      # 2. 配置 Flutter 环境
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0' # 推荐稳定版
          channel: 'stable'

      # 3. 🔍 黑科技：如果没上传 android 目录，自动生成
      - name: Create Android Project if Missing
        run: |
          if [ ! -d "android" ]; then
            echo "⚠️ Android folder not found. Generating scaffold..."
            flutter create . --platforms android
          fi

      # 4. 安装依赖
      - name: Install Dependencies
        run: flutter pub get

      # 5. ✨ 开始打包 (打 Debug 包以免除签名烦恼 且只打包arm64架构)
      # 也就是生成的 APP 可以直接安装，但不能上架谷歌商店 而只打包arm64架构可以充分节省空间
      - name: Build APK
        run: flutter build apk --debug --target-platform android-arm64

      # 6. 上传结果
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: flutter-app-debug
          path: build/app/outputs/flutter-apk/app-debug.apk
```

---


## 🏷️ 【附录】如何设置 APP 中文名称 (显示名称)
**原理**：不使用任何容易报错的 Flutter 插件，直接在打包脚本里定义名字，利用 Linux 命令强制修改安卓配置文件。
**优点**：**绝不报错**、不增加安装包体积、逻辑最简单。
### 1. 紧急修正 `pubspec.yaml`
首先，**必须**把第一行的 `name` 改回英文！否则打包永远报错。

请修改 `pubspec.yaml`：

```yaml
# 1. 内部包名 (身份证)：必须是【小写英文+下划线】
# ❌ 错误: name: "时书"
# ✅ 正确:
name: shishu_diary  
# ... (内容不变) ...
```
### 2. 在 `build.yml` 中定义名字

请直接修改 `.github/workflows/build.yml`。
我们在文件的**最上方**（`env` 区域）定义一个变量，方便你以后随时修改名字。

#### 2.1 添加全局变量
在 `on: workflow_dispatch:` 的下方，添加 `env` 模块：

```yaml
name: Flutter Build Signed Release
on:
  workflow_dispatch:

# 👇👇👇 1. 在这里定义你的中文名 (以后改这里就行) 👇👇👇
env:
  APP_NAME: "你的APP中文名字"
# 👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆

jobs:
  build:
    runs-on: ubuntu-latest
    # ... (后面内容保持不变) ...
```

#### 2.2 添加改名命令

找到 **“Create Android Project”** 这一步，在它**后面**紧接着添加一个新的步骤 **“Change App Name”**。

```yaml
      # ... (上一步：Create Android Project) ...
      - name: Create Android Project
        run: |
          if [ ! -d "android" ]; then
            flutter create . --platforms android --project-name my_diary_app
          fi

      # 👇👇👇 2. 插入这个改名步骤 (直接复制即可) 👇👇👇
      - name: Change App Name (Zero Dependency)
        run: |
          echo "🏷️ Changing App Name to ${{ env.APP_NAME }}..."
          
          # 找到 AndroidManifest.xml
          MANIFEST_FILE=android/app/src/main/AndroidManifest.xml
          
          # 使用 sed 命令强制替换 label 属性
          # 逻辑：找到 android:label="xxx" 替换为 android:label="你的中文名"
          sed -i 's/android:label="[^"]*"/android:label="${{ env.APP_NAME }}"/g' $MANIFEST_FILE
          
          # 打印一下确认修改成功
          grep "android:label" $MANIFEST_FILE

      # ... (下一步：Fix Android Environment) ...
```

**以后让AI提前在代码头部区域定义好占位中文名称，就能方便你修改啦！**
### 🏆 完美版：英文压缩包名和中文APP名
注意:一定要在脚本头部记得帮我定义好APP中文名，方便我更改。并且“最近任务”列表处APP名字与此中文名保持一致。压缩包和安装包名可以是英文名。
#### 1. 修改 `lib/main.dart` (修复运行时标题)
这是 APP 运行后，在手机“最近任务”列表里显示的名字。
请打开 `lib/main.dart`，修改 `MaterialApp` 的 `title`：

```dart
// 找到这里
return MaterialApp(
  title: '中文名', // 👈 改这里，原来是 LOFTER Fixer
  debugShowCheckedModeBanner: false,
  // ...
```
**可以令AI在该文件头部定义该名称，你可以直接在头部修改。**
#### 2. 修改 `.github/workflows/build.yml` (修复安装名与下载名)

请**直接替换**原来的 `build.yml` 中的 **Environment** 和 **Change App Name** 部分。

我们采用 **“文件名用英文，内部属性用中文”** 的策略。因为压缩包用中文会乱码。

```yaml
# ... 前面内容不变 ...

# 👇👇👇 【修改点1】全局变量改用英文 (解决下载文件名乱码) 👇👇👇
env:
  # 这是下载文件的名字 (必须英文)
  FILE_NAME: "英文名"
  # 这是安装到手机上显示的中文名
  APP_LABEL: "APP中文名"

jobs:
  build:
    runs-on: ubuntu-latest
    
    # 👇👇👇 【修改点2】强制设置 UTF-8 环境 (解决 sed 写入中文乱码) 👇👇👇
    env:
      LANG: "en_US.UTF-8"

    steps:
      # ... (Checkout, Java, Flutter 步骤不变) ...

      - name: Create Android Project
        run: |
          if [ ! -d "android" ]; then
            flutter create . --platforms android --project-name lofter_fixer
          fi

      # 👇👇👇 【修改点3】精准注入中文名 👇👇👇
      - name: Change App Name (UTF-8 Safe)
        run: |
          # 1. 找到 Manifest 文件
          MANIFEST="android/app/src/main/AndroidManifest.xml"
          
          # 2. 使用 python 脚本写入中文 (比 sed 更稳，不会乱码)
          # 这一步会精准把 label="xxx" 替换为 label="去水印神器"
          python3 -c "
          import re
          with open('$MANIFEST', 'r', encoding='utf-8') as f:
              content = f.read()
          new_content = re.sub(r'android:label=\"[^\"]*\"', 'android:label=\"${{ env.APP_LABEL }}\"', content)
          with open('$MANIFEST', 'w', encoding='utf-8') as f:
              f.write(new_content)
          "
          echo "✅ App label changed to: ${{ env.APP_LABEL }}"

      # ... (Fix Android Environment, ProGuard, Dependencies, Keystore 等步骤不变) ...

      # ... (Build APK 步骤不变) ...

      # 👇👇👇 【修改点4】重命名为英文文件名 👇👇👇
      - name: Rename and Upload
        run: |
          # 使用英文变量 FILE_NAME 重命名
          mv build/app/outputs/flutter-apk/app-release.apk "build/app/outputs/flutter-apk/${{ env.FILE_NAME }}.apk"

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          # 下载按钮的名字也用英文
          name: ${{ env.FILE_NAME }}_Install_Package
          path: "build/app/outputs/flutter-apk/${{ env.FILE_NAME }}.apk"
```

#### 💡 效果预览
改完后重新打包：
1.  **GitHub 网页上**：下载包叫 `英文名Install_Package.zip`（纯英文，**无乱码**）。
2.  **解压后**：文件叫 `中文名.apk`。
3.  **安装到手机**：图标下面显示的是 **“APP中文名”**（中文显示正常）。
4.  **打开APP**：标题栏显示 **“APP中文名”**。

## 🛡️ 【附录】Flutter 云打包避坑指南 & 故障排除手册
### 🚨  Kotlin 版本冲突 (Duplicate Class / Module Version Error)
这是艰难的关卡，也是解决问题的关键手。

*   **现象**：
    *   报错 `Duplicate class ... found in modules kotlin-stdlib-1.8.10 and 1.7.10`。
    *   或者 `Module was compiled with incompatible version of Kotlin. Expected 1.7.1, found 1.9.0`。
*   **原因**：
    *   新版插件（如 `share_plus`）是用新版 Kotlin (1.9.0) 编译的。
    *   云端 `flutter create` 生成的默认安卓工程还在用旧版 Kotlin 编译器 (1.7.1)。
    *   **新引擎装不进旧底盘，直接报错。**
*   **❌ 失败尝试**：
    *   使用 Gradle 的 `resolutionStrategy` 强行指定库版本（治标不治本，编译器本身版本过低依然无法解析）。
*   **✅ 终极解法 (升级编译器)**：
    *   修改 `android/settings.gradle`（新版 Flutter 控制插件版本的地方），将 Kotlin 插件版本强制改为 **1.9.0**。
    *   命令参考：
        ```bash
        sed -i 's/id "org.jetbrains.kotlin.android" version ".*"/id "org.jetbrains.kotlin.android" version "1.9.0"/g' android/settings.gradle
        ```

### 📉  最低系统版本限制 (MinSDK Error)
*   **现象**：
    *   报错 `uses-sdk:minSdkVersion 16 cannot be smaller than version 21 declared in library [share_plus]`.
*   **原因**：
    *   Flutter 默认模板为了兼容性，将 MinSDK 设为 16 (Android 4.1)。
    *   现代插件（如文件分享、WebView）通常要求最低 Android 5.0 (API 21)。
*   **✅ 解法**：
    *   修改 `android/app/build.gradle`。
    *   命令参考：
        ```bash
        sed -i 's/minSdkVersion.*/minSdkVersion 21/g' android/app/build.gradle
        ```

> **核心经验总结**：
> Flutter 的生态更新极快，GitHub Actions 云端生成的默认安卓工程骨架（Scaffold）往往滞后于最新插件的要求。
> 解决“版本打架”的终极奥义，不是降级插件，而是强制升级编译环境（Kotlin 版本 & MinSDK）。

### 📦 APK 体积“虚胖” (140MB -> 15MB)
*   **现象**：
    *   刚刚打包出来的 APK 巨大无比（>100MB）。
*   **原因**：
    1.  **Debug 模式**：包含 JIT 引擎和调试符号，资源未压缩。
    2.  **Fat APK**：默认包含 `arm64`, `armv7`, `x86` 三套内核。
    3.  **资源过大**：引入了未经压缩的高清图或全量字体文件。
*   **✅ 解法**：
    *   **开启 Release**：`flutter build apk --release` (开启混淆与压缩)。
    *   **指定架构**：`--target-platform android-arm64` (只保留主流机型内核)。
    *   **云端签名**：使用 `keytool` 现场生成临时密钥，骗过 Release 签名校验。

### 📛 项目命名规范 (Invalid Package Name)
*   **现象**：
    *   `flutter create .` 报错 `not a valid Dart package name`。
*   **原因**：
    *   GitHub 仓库名包含了**大写字母**（如 `Flutter_App`），但 Flutter 强制要求包名全小写且用下划线分隔（snake_case）。
*   **✅ 解法**：
    *   在生成工程时显式指定名字：
        ```bash
        flutter create . --platforms android --project-name my_diary_app
        ```

### 📝 脚本编写技巧 (Sed & Grep)
*   **教训**：
    *   不要在 CI 脚本里使用 `grep` 来做“前置检查”（如 `grep "text" file`）。
    *   **原因**：如果 `grep` 没找到文本，会返回 Exit Code 1，导致整个 Action 直接被判定为失败并终止。
    *   **建议**：直接使用 `sed` 进行替换，或者使用 `cat >>` 进行追加写入，这些命令即使没起作用通常也不会报错中断流程。
#### **6、 智能故障转移 (Smart Failover)**

*   **💥 现象**：
    *   用浏览器解析太慢（几秒），用 API 解析快但不稳定（有些链接解不开）。
*   **✅ 解法**：
    *   **双保险策略**：
        1.  优先尝试 **正则+API** (极速模式)，0.1秒解决战斗。
        2.  如果失败（返回空/解析不了），**自动无缝切换**到 WebView (深度模式)，浏览器加载该链接，获取 Cookie，再次尝试下载。
    *   这能保证 90% 的情况极速响应，10% 的疑难杂症也能兜底成功。
---

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

---

**核心心法总结：**
> **“对于反爬虫机制，不要试图用代码去模拟浏览器的每一个行为（那样太累且易碎），而是直接在 APP 里养一个‘真实的浏览器’，利用它去开路，然后窃取它的成果（URL、Cookie）。”**

