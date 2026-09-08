# 音乐接入

打开 `scenes/music_manager.tscn`，选中 MusicManager，在检查器里拖入音频并保存。主场景已引用此文件。若主场景之前一直开着，可保存当前编辑后重新打开主场景。

| 配置项 | 自动播放时机 |
| --- | --- |
| Day Music | 白天，包括第一天和新一天 |
| Dusk Music | 黄昏 |
| Night Music | 黑夜 |
| Page Turn Music | 翻页 |
| Win Music | 胜利结算 |
| Lose Music | 失败结算 |

- 音频放进项目目录后再拖入，推荐 OGG；也支持 Godot 可导入的 MP3、WAV。
- 空槽位会淡出至静音；想延续上一阶段音乐，可给两个阶段配置同一音频。
- Music Volume：音乐音量，默认 0.7；Muted：静音；Fade Seconds：切换淡入淡出秒数，默认 1 秒。
- Loop Music：默认开启，曲目播完自动重播。需要无缝循环时，在音频导入设置中开启 Loop；如果希望只播一次，需要同时关闭此处和音频导入设置中的循环。
- 编辑器预览不播放音乐。当前暂停/设置菜单保持背景音乐播放，重开游戏从白天音乐开始。
- Effects Volume 单独控制音效；Effect Gains 可单独调低某一类音效。按钮悬停声与投掷声已降低音量。

## 后续增加场景

在 Extra Music 字典添加名称和对应音频，例如 `MENU`。游戏代码通过 `Main/Systems/MusicManager` 调用：

```gdscript
music_manager.play_context("MENU")
music_manager.play_stream(audio_stream) # 直接指定音频
music_manager.stop_music() # 淡出停止
music_manager.music_volume = 0.5
music_manager.muted = true
```

自定义播放会在下一次昼夜阶段变化时由自动音乐接管。已接入 arsset/music 中的正式音频：白昼用于 DAY 和 DUSK，夜晚用于 NIGHT；黄昏.mp3 按当前要求不使用。PAGE_TURN 背景音乐留空，纸张翻页通过独立音效通道播放一次。背景音量 0.5、音效音量 0.7、循环与切换淡化 0.8 秒。

音效事件：hover（鼠标进入可用按钮一次）、place（枝条成功贴上）、page（进入翻页）、throw（松子发射）、death（敌人真正死亡）、hurt（扣血）、sun/water（对应资源成功收集）。失败放置和松子第一次命中不播放放置/死亡声。音效可通过 play_effect(event) 调用，同时最多 12 路播放。
