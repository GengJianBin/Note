# 一、webrtc下载及编译
## 1.1 Windows平台
[参考链接](https://webrtc.github.io/webrtc-org/native-code/development/)

### 1.1.1 下载命令
```cmd
mkdir webrtc-checkout
cd webrtc-checkout
fetch --nohooks webrtc
gclient sync
```

### 1.1.2 生成工程文件
``` cmd
gn gen out/Default
gn gen out/vs_release_x64 --ide=vs2022 --args="is_debug=false target_cpu=\"x64\""
```

### 1.1.3 编译命令
` ninja -C out/Default `

### 1.1.4下载源码遇到的问题
#### 1.1.4.1 window平台下文件名称过长问题
`git config --system core.longpaths true`
#### 1.1.4.2 下载报错：
```cmd
WARNING: subprocess '"git" "-c" "core.deltaBaseCacheLimit=2g" "clone" "--no-checkout" "--progress" 
"https://chromium.googlesource.com/chromium/src/third_party" 
"C:\gengjianbin\workspace\code\openSource\gwebgrtc\webrtc_20230527\webrtc-checkout\src\_gclient_third_party_803d3biw"' 
in C:\gengjianbin\workspace\code\openSource\gwebgrtc\webrtc_20230527\webrtc-checkout failed; will retry after a short nap...
```
这是git的使用问题
```cmd
fetch --nohooks --no-history android
gclient sync -D --no-history  //执行该命令就可以
```
#### 1.1.4.3 下载代码报错：
```cmd
错误信息：our local changes to the following files would be overwritten by merge:
git reset --hard
```
#### 1.1.4.4 下载第三方库失败
错误信息：
#### 1.1.4.5 git命令的使用
- 拉代码
`git pul origin 当前分支名`
- 查看当前分支 
`git branch -a`
- 查看当前分支状态
`git status`
- 保存当前分支的修改
`git stash`
- 恢复之前保存的修改
`git stash pop`
- 放弃本地修改，直接覆盖
`git reset --hard`
- 暂存本地修改
`git add *`

### 1.1.5 生成工程错误
#### 1.1.5.1 gn gen out/Default 生成工程错误
```cmd
Toolchain is out of date. Run "gclient runhooks" to update the toolchain, or set DEPOT_TOOLS_WIN_TOOLCHAIN=0 to use the locally installed toolchain.
Note: DEPOT_TOOLS_WIN_TOOLCHAIN=0 does not work with remote execution.
Traceback (most recent call last):
  File "C:\Workspace\openSource\webrtc\webrtc-checkout\src\build\vs_toolchain.py", line 656, in <module>
    sys.exit(main())
             ^^^^^^
  File "C:\Workspace\openSource\webrtc\webrtc-checkout\src\build\vs_toolchain.py", line 652, in main
    return commands[sys.argv[1]](*sys.argv[2:])
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "C:\Workspace\openSource\webrtc\webrtc-checkout\src\build\vs_toolchain.py", line 618, in GetToolchainDir
    runtime_dll_dirs = SetEnvironmentAndGetRuntimeDllDirs()
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "C:\Workspace\openSource\webrtc\webrtc-checkout\src\build\vs_toolchain.py", line 111, in SetEnvironmentAndGetRuntimeDllDirs
    update_result = Update(no_download=True)
                    ^^^^^^^^^^^^^^^^^^^^^^^^
  File "C:\Workspace\openSource\webrtc\webrtc-checkout\src\build\vs_toolchain.py", line 553, in Update
    subprocess.check_call(get_toolchain_args)
  File "C:\Users\13684\AppData\Local\vpython-root.0\store\cpython+gdee0q11ohi0s4eqh0uqprvov4\contents\bin\Lib\subprocess.py", line 413, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['C:\\Users\\13684\\AppData\\Local\\vpython-root.0\\store\\python_venv-beaoibbfdu9519ag5lffgvlsfc\\contents\\Scripts\\python3.exe', 'C:\\Workspace\\openSource\\webrtc\\webrtc-checkout\\src\\third_party\\depot_tools\\win_toolchain\\get_toolchain_if_necessary.py', '--output-json', 'C:\\Workspace\\openSource\\webrtc\\webrtc-checkout\\src\\build\\win_toolchain.json', '68a20d6dee', '--no-download']' returned non-zero exit status 1.
ERROR at //build/config/win/visual_studio_version.gni:29:7: Script returned non-zero exit code.
      exec_script("../../vs_toolchain.py", [ "get_toolchain_dir" ], "scope")
      ^----------
Current dir: C:/Workspace/openSource/webrtc/webrtc-checkout/src/out/Default/
Command: C:/Users/13684/AppData/Local/vpython-root.0/store/python_venv-beaoibbfdu9519ag5lffgvlsfc/contents/Scripts/python3.exe C:/Workspace/openSource/webrtc/webrtc-checkout/src/build/vs_toolchain.py get_toolchain_dir
Returned 1.
See //build/gn_logs.gni:42:3: whence it was imported.
  import("//build/config/win/visual_studio_version.gni")
  ^----------------------------------------------------
See //BUILD.gn:841:3: whence it was imported.
  import("//build/gn_logs.gni")
  ^---------------------------
```
解决办法：gclient runhooks

#### 1.1.5.2 gclient runhooks错误
```cmd
Updating depot_tools...
fatal: unable to read config file 'C:/Users/13684/.gitconfig': No such file or directory
WARNING:root:Failed to read your global Git config:
Command '['C:\\Workspace\\tools\\depot_tools\\depot_tools\\git.bat', 'config', '--list', '--global', '-z']' returned non-zero exit status 128.

WARNING:root:depot_tools recommends setting the following for
optimal Chromium development:

$ git config --global core.autocrlf false
$ git config --global core.filemode false
$ git config --global core.fscache true
$ git config --global core.preloadindex true

You can silence this message by setting these recommended values.

You can allow depot_tools to automatically update your global
Git config to recommended settings by running:
$ git config --global depot-tools.allowGlobalGitConfig true

To suppress this warning and silence future recommendations, run:
$ git config --global depot-tools.allowGlobalGitConfig false
Error: Command 'python3 src/build/landmines.py --landmine-scripts src/tools_webrtc/get_landmines.py --src-dir src' returned non-zero exit status 9009 in C:\Workspace\openSource\webrtc\webrtc-checkout
```
解决办法：
在目录C:\Users\13684下生成.gitconfig全局配置
- 首先确保Git已正确安装并添加到系统PATH
`git --version  # 检查Git是否可用`

- 创建并配置全局Git配置
```cmd
git config --global user.name "gengjianbin"  # 替换为你的名称
git config --global user.email "13684522822@163.com"  # 替换为你的邮箱
```
- 设置depot_tools推荐的Git配置
```cmd
git config --global core.autocrlf false
git config --global core.filemode false
git config --global core.fscache true
git config --global core.preloadindex true
```
- 允许depot_tools自动使用全局配置（可选，用于消除警告）
`git config --global depot-tools.allowGlobalGitConfig true`

#### 1.1.5.3 如无工具链可更新
- depot_tools不更新：设置DEPOT_TOOLS_UPDATE = 0
- DEPOT_TOOLS_WIN_TOOLCHAIN=0

#### 1.1.5.4 设置DEPOT_TOOLS_UPDATE = 0 和 DEPOT_TOOLS_WIN_TOOLCHAIN=0后执行gn gen out/Default报错
找不到LASTCHANGE.committime，确认python路径是否在PATH中的第一个，一般Windows中Appstore中的python会是第一个

注意：4.1报错，通过4.2方式解决，4.2报错，通过4.3方式解决，4.3报错，通过4.4或4.5方式解决

#### 1.1.5.5 执行 gn gen /out/Default报错
```cmd
Traceback (most recent call last):
  File "C:\Workspace\openSource\webrtc\webrtc-checkout\src\build\compute_build_timestamp.py", line 138, in <module>
    sys.exit(main())
             ^^^^^^
  File "C:\Workspace\openSource\webrtc\webrtc-checkout\src\build\compute_build_timestamp.py", line 111, in main
    last_commit_timestamp = int(open(lastchange_file).read())
                                ^^^^^^^^^^^^^^^^^^^^^
FileNotFoundError: [Errno 2] No such file or directory: 'C:\\Workspace\\openSource\\webrtc\\webrtc-checkout\\src\\build\\util\\LASTCHANGE.committime'
ERROR at //build/timestamp.gni:43:19: Script returned non-zero exit code.
build_timestamp = exec_script(compute_build_timestamp,
                  ^----------
Current dir: C:/Workspace/openSource/webrtc/webrtc-checkout/src/out/Default/
Command: C:/Users/13684/AppData/Local/vpython-root.0/store/python_venv-beaoibbfdu9519ag5lffgvlsfc/contents/Scripts/python3.exe C:/Workspace/openSource/webrtc/webrtc-checkout/src/build/compute_build_timestamp.py default
Returned 1.
See //build/config/win/BUILD.gn:13:1: whence it was imported.
import("//build/timestamp.gni")
^-----------------------------
See //build/config/BUILDCONFIG.gn:392:5: which caused the file to be included.
    "//build/config/win:default_crt",
    ^-------------------------------
```
解决办法：更新代码 gclient sync

#### 1.1.5.6 执行 gn gen /out/Default报错
错误信息：
```cmd 
C:\gengjianbin\workspace\code\openSource\gwebgrtc\chrome_webrtc\webrtc-checkout\src>gn gen out/Default
ERROR at //build/config/compiler/BUILD.gn:1508:22: Script returned non-zero exit code.
    clang_revision = exec_script("//tools/clang/scripts/update.py",
                     ^----------
Current dir: C:/gengjianbin/workspace/code/openSource/gwebgrtc/chrome_webrtc/webrtc-checkout/src/out/Default/
Command: C:/gengjianbin/workspace/code/openSource/gwebgrtc/webrtc/depot_tools/bootstrap-2@3_8_10_chromium_26_bin/python3/bin/python3.exe C:/gengjianbin/workspace/code/openSource/gwebgrtc/chrome_webrtc/webrtc-checkout/src/tools/clang/scripts/update.py --print-revision --verify-version=17
Returned 1 and printed out:

The expected clang version is llvmorg-17-init-12166-g7586aeab-3 but the actual version is
Did you run "gclient sync"?

See //build/config/BUILDCONFIG.gn:348:3: which caused the file to be included.
  "//build/config/compiler:no_unresolved_symbols",
  ^----------------------------------------------
Traceback (most recent call last):
  File "C:/gengjianbin/workspace/code/openSource/gwebgrtc/chrome_webrtc/webrtc-checkout/src/build/compute_build_timestamp.py", line 137, in <module>
    sys.exit(main())
  File "C:/gengjianbin/workspace/code/openSource/gwebgrtc/chrome_webrtc/webrtc-checkout/src/build/compute_build_timestamp.py", line 111, in main
    last_commit_timestamp = int(open(lastchange_file).read())
FileNotFoundError: [Errno 2] No such file or directory: 'C:\\gengjianbin\\workspace\\code\\openSource\\gwebgrtc\\chrome_webrtc\\webrtc-checkout\\src\\build\\util\\LASTCHANGE.committime'
```
解决办法：
执行gclient sync

### 1.1.6 webrtc 更新代码
- 不覆盖更新
假设src/third_party目录存在已修改未提交的文件
```cmd 
cd src/third_party
git stash
cd ../..
gclient sync --with_branch_heads --with_tags
cd src/third_party
git stash pop
```
- 强制覆盖更新
`gclient sync -f --with_branch_heads --with_tags`

### 1.1.7 总结：
- 安装好deopt_tools python2环境后，直接按照步骤同步即可下载成功。如有错误按照上述问题可解决，window和mac下相同。
- 第三方库容易下载失败，可单独下载同步（使用git丢弃更改，重新更新代码）。 ———— 在2023-11-16日三方库下载失败中已经验证过，先丢弃代码（需要先设置文件名最大长度），更新出问题的模块（本次下载失败的模块为libc++），再执行gclient sync -D --no-history 后下载成功，可生成工程，编译通过。

## 1.2 Linux平台
### 1.2.1 depot_tools 安装
- 下载 `git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git`
- 设置环境变量(使用pyenv管理python时,depot_tools添加的环境变量，应该位于pyenv的环境变量之后)
```bash
# 若使用bash（绝大多数Linux默认）
echo 'export PATH="$PATH:~/tools/depot_tools"' >> ~/.bashrc

# 若使用zsh（如Oh My Zsh）
echo 'export PATH="$PATH:~/tools/depot_tools"' >> ~/.zshrc

# 生效配置（无需重启终端）
source ~/.bashrc  # bash用户
# 或 source ~/.zshrc  # zsh用户
```

### 1.2.2 将depot_tools中的python添加到pyenv中管理
```bash
# 1.创建软连接
# 软链接depot_tools的Python到该目录
ln -s ~/Workspace/tools/depot_tools/ ~/.pyenv/versions/3.10.12-python3-rtc

# 2.取消软连接
# 先确认目录存在（避免删错）
ls -l ~/.pyenv/versions/3.10.12-rtc

# 删除该版本目录（软链接和目录一起删除）
rm -rf ~/.pyenv/versions/3.10.12-rtc

# 验证是否删除成功（无输出即删除完成）
ls ~/.pyenv/versions/3.10.12-rtc
```

### 1.2.3 下载rtc代码
```bash
mkdir webrtc-checkout
cd webrtc-checkout
fetch --nohooks webrtc
gclient sync
```
若使用的时WSL,并且已经将pyenv-win添加到了Windows的PATH中，需要禁止启动WSL时将Windows的环境变量添加到WSL的及环境变量中，防止pyenv-win中的fetch中的回车换行和Linux中不一致而报错。
```bash
# 一、禁止WSL加载Windows系统的PATH变量
# 1.编辑 WSL 的配置文件 /etc/wsl.conf（没有则创建）：
sudo vim /etc/wsl.conf
# 2. 添加以下内容：
[interop]
appendWindowsPath = false
# 3.关闭 WSL 终端，在 Windows 的 cmd 中执行以下命令重启 WSL(必须在Windows cmd中执行以下命令后在重启WSL，直接关闭WSL后再重新打开不生效)：
wsl --shutdown

二、去除WSL中PATH中设置错误的路径
# 4.搜索.bashrc中包含~/tools/depot_tools的行（bash用户）
grep -n '~/tools/depot_tools' ~/.bashrc
# 5.如果步骤4失败，则搜索所有用户配置文件
grep -r '~/tools/depot_tools' ~/
# 验证当前PATH中无~，且depot_tools路径仅出现一次
echo $PATH | tr ':' '\n' | grep depot_tools
# 匹配错误路径特征，删除对应行（转义必要的特殊字符）
sed -i '/export PATH="\$PATH:\~\/tools\/depot_tools"/d' ~/.bash_history
# vi中清空文件
命令模式下输入%d

```
### 1.2.4 编译
```bash
# 基础编译（Debug版，x86_64，默认功能）
gn gen out/Default --args='
target_os="linux"
target_cpu="x64"
is_debug=true  # true=Debug版（调试用），false=Release版（发布用）
is_component_build=false  # 静态编译（生成单个库）
rtc_use_h264=true  # 启用H264（需系统有openh264依赖）
use_rtti=true  # 启用RTTI（调试方便）
enable_libaom=true  # 启用AV1编码
'
# 精简版（Release版，仅核心功能，体积更小）
gn gen out/Release --args='
target_os="linux"
target_cpu="x64"
is_debug=false
is_component_build=false
rtc_use_h264=true
rtc_include_tests=false  # 关闭测试代码
rtc_enable_simulcast=true  # 启用 simulcast
'
```
### 1.2.5 执行编译
```bash
# 编译所有目标（耗时久，适合首次编译）
ninja -C out/Default  # 对应gn gen的目录（out/Default）

# 仅编译核心库（rtc_base + peerconnection，加快速度）
ninja -C out/Default webrtc

# 仅编译示例程序（如peerconnection_client/server）
ninja -C out/Default peerconnection_client peerconnection_server
```