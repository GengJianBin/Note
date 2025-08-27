REM 1.download
REM mkdir webrtc-checkout
REM cd webrtc-checkout
REM fetch --nohooks webrtc

REM 2.set output format
REM https://ninja-build.org/manual.html
REM 设置输出的显示格式
REM %s  The number of started edges.
REM %t  The total number of edges that must be run to complete the build.
REM %p  The percentage of finished edges.
REM %r  The number of currently running edges.
REM %u  The number of remaining edges to start.
REM %f  The number of finished edges.
REM %o  Overall rate of finished edges per second
REM %c  Current rate of finished edges per second (average over builds specified by -j or its default)
REM %e  Elapsed time in seconds. (Available since Ninja 1.2.)
REM %E  Remaining time (ETA) in seconds. (Available since Ninja 1.12.)
REM %w  Elapsed time in [h:]mm:ss format. (Available since Ninja 1.12.)
REM %W  Remaining time (ETA) in [h:]mm:ss format. (Available since Ninja 1.12.)
REM %P  The percentage (in ppp% format) of time elapsed out of predicted total runtime. (Available since Ninja 1.12.)
REM %%  A plain % character.
set NINJA_STATUS=[%f/%t %e sec]

REM 3.genrate project and build
gn gen out/vs_release_x64 --ide=vs2022 --args="is_debug=false target_cpu=\"x64\""
ninja -C out/vs_release_x64