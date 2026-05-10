# Croptails -> DreamFarm 迁移设计

## 目的

这份文档用于评估 `reference/tutorial-components-and-scripts-main/tutorials/croptails` 是否适合作为 `DreamFarm` 的底座，并给出最小风险的吸收方案。

结论先行：

- 不建议把 `croptails` 直接作为 `DreamFarm` 的整套底座替换现有项目。
- 建议把它作为“架构参考库”和“局部实现参考”，按模块逐步吸收。
- 当前最值得吸收的是：
  - 工具状态管理方式
  - 交互对象组件化方式
  - 存档职责拆分方式


## 为什么不适合直接当底座

### 1. 它不是完整独立工程

`reference/tutorial-components-and-scripts-main/tutorials/croptails` 下没有 `project.godot`，当前内容更像教程脚本与资源片段，而不是可直接接管 `DreamFarm` 的完整 Godot 项目。

这意味着：

- 现有脚本依赖原作者工程里的场景结构
- 依赖原作者的 InputMap
- 依赖一组全局 autoload
- 依赖枚举、资源、节点组和命名规则

直接迁移的成本会比重写局部系统更高。


### 2. 它的全局依赖很重

以下脚本都默认存在一整套外部全局环境：

- [game_manager.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scripts/globals/game_manager.gd)
- [tool_manager.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scripts/globals/tool_manager.gd)
- [save_game_manager.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scripts/globals/save_game_manager.gd)
- [inventory_manager.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scripts/globals/inventory_manager.gd)

如果把这些直接并进 `DreamFarm`，结果通常不是“复用”，而是：

- 双套管理器并存
- 保存结构冲突
- 输入事件冲突
- UI 和角色行为耦合变重


### 3. 它是教程式实现，不是现成生产底座

例如：

- [inventory_manager.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scripts/globals/inventory_manager.gd) 只是最小字典计数
- [growth_cycle_component.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scenes/objects/plants/growth_cycle_component.gd) 更适合展示思路，不适合原样照搬
- [tools_panel.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scenes/ui/tools_panel.gd) 是按钮型工具 UI，不适合你现在已经实现的热栏交互

`DreamFarm` 现在已经有：

- 热栏与背包拖拽
- 物品掉落与拾取
- JSON 驱动作物/物品
- 当前存档结构

直接换底座会把这些现有成果全部重新接线，收益不高。


## 哪些部分值得吸收

## 1. 工具状态管理

参考文件：

- [tool_manager.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scripts/globals/tool_manager.gd)
- [tools_panel.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scenes/ui/tools_panel.gd)
- [player.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scenes/characters/player/player.gd)

这套思路的优点：

- UI 不直接做行为
- UI 只负责改变“当前工具”
- 玩家与交互组件只读取当前工具状态
- 角色逻辑和 UI 解耦

对 `DreamFarm` 的启发：

- 现在 `HotbarManager` 已经承担了部分工具选择职责
- 可以继续把“工具选择”和“具体农田交互”再分开
- 目标是让 `FarmScene.gd` 少做 `if hoe / if scythe / if seed` 这种直接分发

建议吸收方式：

- 保留 `HotbarManager`
- 新增一个轻量 `ToolContext` 或让 `HotbarManager` 直接暴露当前工具类型
- 农田交互改成：
  - 先识别工具类别
  - 再调用目标对象自己的 `interact_with_tool(tool_id, actor)` 或类似接口


## 2. 组件化交互对象

参考目录：

- `reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scenes/components/`

这套目录说明原作者把很多交互能力拆成了小组件，例如：

- 可收集
- 可受击
- 可保存
- 可交互

对 `DreamFarm` 的价值不在于原样搬文件，而在于设计方向：

- 农田、树木、矿石、掉落物不应都依赖 `FarmScene.gd` 硬编码判断
- 每种对象应该尽量自己回答：
  - 能不能交互
  - 用什么工具交互
  - 交互后产出什么

建议吸收方式：

- 保留当前 `FarmingTile.gd`
- 后续新增资源点时，不再往 `FarmScene.gd` 堆更多 `match`
- 逐步形成统一接口，例如：
  - `can_interact_with(tool_id: String) -> bool`
  - `interact_with_tool(tool_id: String, actor: Node) -> Dictionary`


## 3. 存档职责拆分

参考文件：

- [save_game_manager.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scripts/globals/save_game_manager.gd)

这套实现本身不复杂，但思路值得借：

- 保存管理器只负责触发保存
- 真正的数据由场景对象或保存组件自己提供

`DreamFarm` 现在的 [SaveManager.gd](D:/XiangMu/DreamFarm/scripts/managers/SaveManager.gd) 已经能工作，但后续如果对象变多，会出现两个风险：

- `SaveManager` 越来越大
- 每加一个系统都要改一遍主存档结构

建议吸收方式：

- 继续保留当前 JSON 存档
- 但逐步把每类对象的存档整理为“对象自己负责序列化”
- 当前农田已经是这个方向：
  - `get_save_data()`
  - `load_save_data(data)`

后续可扩展到：

- 助手角色
- 掉落物
- 动物
- 矿洞资源点


## 哪些部分不建议吸收

## 1. 不建议直接搬它的 InventoryManager

参考文件：

- [inventory_manager.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scripts/globals/inventory_manager.gd)

原因：

- 它只有简单字典计数
- 不支持你现在已经做好的背包格子、拖拽、热栏联动
- 回退到这套只会让 `DreamFarm` 降级


## 2. 不建议直接搬它的工具 UI

参考文件：

- [tools_panel.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scenes/ui/tools_panel.gd)

原因：

- 它是按钮工具栏，不是你现在的底部热栏
- 和你现有的数字键切换、物品图标、拖拽交换模型不一致

可以借鉴“职责分离”，不建议照搬 UI 形式。


## 3. 不建议直接搬它的作物成长实现

参考文件：

- [growth_cycle_component.gd](D:/XiangMu/DreamFarm/reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts/scenes/objects/plants/growth_cycle_component.gd)

原因：

- 强依赖它自己的 `DayAndNightCycleManager`
- 成长状态枚举和你现在的 JSON 数据结构不一致
- 当前 `DreamFarm` 已经改成更适合 MVP 的“实时成长 + 浇水门槛”

可以借它“成长状态组件化”的思路，但不要直接接入。


## DreamFarm 当前适合的迁移路线

## Phase 1: 只吸收设计，不换底座

目标：

- 保持当前 `DreamFarm` 可玩
- 不拆现有存档
- 不推翻热栏/背包/掉落物

动作：

- 保留现有管理器
- 继续用 `HotbarManager + InventoryManager + SaveManager`
- 把 `croptails` 作为参考目录，不直接 `load` 其脚本

这是当前最稳妥方案。


## Phase 2: 抽象工具交互层

目标：

- 让 `FarmScene.gd` 减少工具判断硬编码

建议改动方向：

- 新增轻量工具交互接口
- 农田通过接口处理工具
- 后续树木、石头、矿点也走同一套协议

Phase 2 完成后，项目就会真正开始接近“底座化”。


## Phase 3: 抽象可保存对象层

目标：

- 降低 `SaveManager` 扩张速度

建议改动方向：

- 为世界对象建立统一的存档接口
- `SaveManager` 只负责汇总
- 各系统各自返回自己的可序列化数据


## Phase 4: 引入组件式世界对象

目标：

- 为矿洞、砍树、敲石头、动物、NPC 留扩展位

建议改动方向：

- 不是复制 `croptails/components`
- 而是按 `DreamFarm` 当前需求做最小组件化

优先顺序建议：

1. 工具可交互对象
2. 可收获对象
3. 可保存对象
4. 可掉落对象


## 建议的实际执行策略

如果要把 `croptails` 当“DreamFarm 底座来源”，推荐这样做：

1. 不整体迁移 `croptails`
2. 只把它当作设计样本
3. 从工具交互抽象开始吸收
4. 再做对象组件化
5. 最后整理存档边界

不推荐这样做：

1. 把 `reference/tutorial-components-and-scripts-main/tutorials/croptails/scripts` 直接复制到 `scripts/`
2. 把它的全局单例接到当前项目
3. 再尝试修冲突

那样通常会比继续演进 `DreamFarm` 更乱。


## 最终结论

`croptails` 适合作为：

- 工具系统参考
- 组件化思路参考
- 农场对象结构参考

`croptails` 不适合作为：

- 当前 `DreamFarm` 的直接替换底座
- 可直接复制粘贴进现有工程的完整框架

对 `DreamFarm` 最合理的路线是：

- 保留当前项目
- 吸收 `croptails` 的结构思想
- 分阶段重构局部系统


## 后续建议

下一步最值得做的是：

- 以 `croptails` 为参考，重构 `DreamFarm` 的“工具交互层”

目标效果：

- `HotbarManager` 只管当前工具
- `Player` 只管朝向和触发
- `FarmScene` 只负责定位目标对象
- `FarmingTile` 自己决定如何响应工具

这是把 `DreamFarm` 逐步变成可持续底座的第一步。
