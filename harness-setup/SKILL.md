---
name: harness-setup
description: 为项目搭建或更新长时运行的 coding agent 工作流框架（harness）。当用户说"搭建 harness"、"配置 agent 工作流"、"设置长时运行工作流"、"初始化 coding agent 环境"、"更新/同步/补齐已初始化项目的 harness"、"设置跨会话连续工作"时触发。支持 Java/Maven、Node.js、Python 项目。
---

# Harness 工作流搭建

## 任务目标

- 本 Skill 用于：为项目搭建或保守更新 harness 工作流框架，实现长时运行、跨会话连续的 coding agent 工作流
- 能力包含：
  - 自动检测项目类型（Java/Maven、Node.js、Python）
  - 从模板库生成 init.sh 脚本
  - 从模板库生成所有 harness 文件
  - 对已初始化项目执行保守 update：只补缺失文件和缺失说明，不覆盖已有 harness 状态
- 触发条件：用户提到"搭建 harness"、"配置 agent 工作流"、"初始化 coding agent 环境"、"更新 harness"、"同步 harness"、"补齐 harness 文件"等关键词

## 前置准备

- 项目根目录已存在

## 模式选择

先判断目标项目是否已经初始化过 harness：

| 条件 | 模式 | 行为 |
|------|------|------|
| 不存在 `harness/` 目录 | 初始化模式 | 创建完整 harness 框架 |
| 已存在 `harness/` 目录 | 保守 update 模式 | 只补齐缺失文件和缺失说明，不覆盖已有状态 |

保守 update 模式不是重新初始化。它的目标是让旧项目获得当前 Skill 新增的文件和规则，同时保留项目已有进度、功能清单、memory、脚本定制和人工修改。

## 资源索引

### 脚本文件（`script/` 目录）

| 文件 | 项目类型 | 说明 |
|------|----------|------|
| `script/init-java.sh` | Java/Maven | 含 Maven/Java 检查、项目声明 JDK 版本识别、Profile 切换 |
| `script/init-node.sh` | Node.js | 含 Node/npm 检查、npm install/test/dev |
| `script/init-python.sh` | Python | 含虚拟环境、pip/pytest、python3 启动 |

### 运行时版本策略

模板脚本不得硬编码项目特定运行时版本。需要显式覆盖时使用环境变量；没有显式覆盖时，版本约束应来自目标项目本身。

Java/Maven 项目按以下顺序确定 JDK 主版本：

1. `REQUIRED_JAVA_VERSION` 环境变量
2. `pom.xml` 中的 `<maven.compiler.release>`、`<maven.compiler.source>`、`<maven.compiler.target>`、`<java.version>`
3. `.java-version`、`.sdkmanrc`、`.tool-versions`
4. 如果都没有声明，则使用当前 Java 环境并给出提示，不强制版本

### 模板文件（`template/` 目录）

| 文件 | 用途 | 占位符 |
|------|------|--------|
| `template/feature_list.json` | 功能状态清单 | `{{PROJECT_NAME}}` `{{DATE}}` |
| `template/claude-progress.md` | 会话进度日志 | `{{PROJECT_ROOT}}` `{{VERIFY_COMMAND}}` `{{PROJECT_TYPE}}` `{{BUILD_TOOL}}` `{{DATE}}` |
| `template/session-handoff.md` | 会话交接摘要 | `{{VERIFY_COMMAND}}` `{{DEBUG_COMMANDS}}` |
| `template/CLAUDE.md` | 主 Claude 会话指令 | 无（可直接复制） |
| `template/AGENTS.md` | 多 agent 工作流规则 | 无（可直接复制） |
| `template/user-memory.md` | 全局用户偏好，跨项目共享（复制到 `~/harness/`） | 无（直接复制，已存在时不覆盖） |
| `template/project-memory.md` | 项目级偏好，仅当前项目生效 | `{{PROJECT_NAME}}` `{{DATE}}` |

## 初始化模式操作步骤

### 步骤 1：确认项目类型

检测项目根目录下的特征文件：

| 特征文件 | 项目类型 | 使用脚本 |
|----------|----------|----------|
| `pom.xml` | Java/Maven | `script/init-java.sh` |
| `package.json` | Node.js | `script/init-node.sh` |
| `requirements.txt` / `pyproject.toml` | Python | `script/init-python.sh` |

如果无法确定，询问用户。

### 步骤 2：创建 harness 目录

```bash
mkdir -p harness
```

### 步骤 3：复制 init.sh

从 `script/` 目录读取对应项目类型的脚本，复制到目标项目的 `harness/init.sh`，然后设置执行权限：

```bash
chmod +x harness/init.sh
```

**注意**：复制后检查脚本中的 `ROOT_DIR` 是否指向项目根目录（`SCRIPT_DIR/..`），不要指向 harness 目录。

对于 Java 多模块项目，可能需要调整启动命令中的 `-pl <module-name>` 参数。

### 步骤 4：复制模板文件

从 `template/` 目录读取以下文件，替换占位符后复制到目标项目的 `harness/` 目录：

1. `feature_list.json` → 替换 `{{PROJECT_NAME}}` 和 `{{DATE}}`
2. `claude-progress.md` → 替换所有占位符
3. `session-handoff.md` → 替换 `{{VERIFY_COMMAND}}` 和 `{{DEBUG_COMMANDS}}`
4. `project-memory.md` → 替换 `{{PROJECT_NAME}}` 和 `{{DATE}}`，复制到 `./harness/project-memory.md`

### 步骤 4.5：初始化全局 memory

全局 memory 用于记录跨所有项目共享的用户偏好（代码风格、提交规范等）。

- 如果 `~/harness/` 目录不存在：`mkdir -p ~/harness`
- 如果 `~/harness/user-memory.md` **不存在**：从 `template/user-memory.md` 复制过去，让用户后续按需填写
- 如果 **已存在**：**不覆盖**，保留用户已积累的偏好（这是关键，避免丢失用户配置）

### 步骤 5：生成 CLAUDE.md 和 AGENTS.md

- 如果目标项目**不存在**这两个文件：从 `template/` 目录直接复制
- 如果目标项目**已存在**这两个文件：
  1. 不要整体覆盖已有内容
  2. 检查路径引用是否正确（必须是 `./harness/init.sh` 或 `harness/init.sh`，不能是旧的 `./init.sh`）
  3. 检查是否已有等效的 memory 写入规则和必需文件说明
  4. 如果没有等效规则，只追加一个小节，说明：
     - `~/harness/user-memory.md` 是跨项目偏好的主要 harness 写入位置
     - `harness/project-memory.md` 是当前项目偏好的主要 harness 写入位置
     - 用户要求“记住”“以后”“下次”或表达稳定偏好时，必须先写入对应的 harness memory
     - 如果 Claude Code auto-memory 也记录偏好，可以同步/镜像，但不得只写入 auto-memory；冲突时以 harness memory 为准

“等效规则”按语义判断，不要求文本完全一致；重复运行时不得追加重复小节。

### 步骤 6：验证

运行 `./harness/init.sh` 验证脚本工作正常。

## 保守 update 模式操作步骤

当目标项目已存在 `harness/` 目录时，进入保守 update 模式。不要跳过，也不要整体覆盖。

### Update 步骤 1：确认项目类型

仍然按初始化模式的特征文件判断项目类型，用于决定缺失 `harness/init.sh` 时应复制哪个脚本。如果无法判断且 `harness/init.sh` 已存在，可以继续补齐通用模板文件；如果无法判断且 `harness/init.sh` 缺失，询问用户。

### Update 步骤 2：补齐缺失 harness 文件

逐一检查当前 Skill 的脚本和模板目标文件：

| 目标文件 | 缺失时 | 已存在时 |
|----------|--------|----------|
| `harness/init.sh` | 按项目类型复制对应脚本并 `chmod +x` | 不覆盖，保留项目定制 |
| `harness/feature_list.json` | 从模板生成 | 不覆盖，保留功能状态 |
| `harness/claude-progress.md` | 从模板生成 | 不覆盖，保留进度日志 |
| `harness/session-handoff.md` | 从模板生成 | 不覆盖，保留交接内容 |
| `harness/project-memory.md` | 从模板生成 | 不覆盖，保留项目偏好 |

如果未来模板库新增文件，也按同一规则处理：缺失才创建，已存在则保留。

### Update 步骤 3：初始化全局 memory

`~/harness/user-memory.md` 仍然是 create-only：

- 不存在时，从 `template/user-memory.md` 复制
- 已存在时，绝不覆盖

### Update 步骤 4：补齐 CLAUDE.md / AGENTS.md 说明

对于目标项目根目录的 `CLAUDE.md` 和 `AGENTS.md`：

- 文件缺失：从模板复制
- 文件存在：不得整体覆盖，只做窄范围语义补充
- 检查是否已有等效说明：
  - 启动路径使用 `./harness/init.sh` 或 `harness/init.sh`，不是旧的 `./init.sh`
  - 必需文件包含 `harness/feature_list.json`、`harness/claude-progress.md`、`harness/init.sh`、`harness/session-handoff.md`、`harness/project-memory.md`
  - 全局偏好位置是 `~/harness/user-memory.md`
  - 项目偏好位置是 `harness/project-memory.md`
  - 用户要求“记住”“以后”“下次”或表达稳定偏好时，必须先写入对应的 harness memory
  - 如果 Claude Code auto-memory 也记录偏好，可以同步/镜像，但不得只写入 auto-memory；冲突时以 harness memory 为准

只有缺少等效说明时，才追加一个简短小节。重复运行时不得追加重复小节。判断“等效说明”按语义，不要求文本完全一致。

推荐追加小节：

```markdown
## Harness memory 与重启路径

- 标准重启入口是 `./harness/init.sh`。
- 项目状态以 `harness/feature_list.json`、`harness/claude-progress.md`、`harness/session-handoff.md` 为准。
- 跨项目偏好写入 `~/harness/user-memory.md`；当前项目偏好写入 `harness/project-memory.md`。
- 用户要求“记住”“以后”“下次”或表达稳定偏好时，先写入对应的 harness memory。
- 如果其他 memory 机制也记录偏好，可以同步或镜像，但不得只写入 auto-memory；冲突时以 harness memory 为准。
```

### Update 步骤 5：报告保留和补齐结果

结束时明确报告：

- 本次新创建了哪些缺失文件
- 哪些已有文件被保留且未覆盖
- `CLAUDE.md` / `AGENTS.md` 是否追加了缺失说明
- 哪些已有文件可能和当前模板不同，需要人工对比
- `./harness/init.sh` 是否运行成功

### Update 步骤 6：验证

如果 `harness/init.sh` 存在，运行：

```bash
./harness/init.sh
```

如果验证失败，报告失败命令和错误，不要声称 update 完成。不要为了让验证通过而覆盖用户已有脚本或删除项目状态。

## 使用示例

- 示例 1：
  - 场景：用户在新 Java 项目中说"帮我搭建 harness 工作流"
  - 操作：检测到 `pom.xml` → 复制 `script/init-java.sh` → 复制模板文件并替换占位符 → 运行验证
  - 预期产出：完整的 harness 框架
  - 关键要点：从项目配置识别 JDK 版本，检查 Maven 是否可用；模板本身不写死 JDK 版本

- 示例 2：
  - 场景：用户说"配置 agent 工作流，这是一个 Node.js 项目"
  - 操作：复制 `script/init-node.sh` → 复制模板文件 → 运行验证
  - 预期产出：完整的 harness 框架，init.sh 使用 npm 命令

- 示例 3：
  - 场景：项目已有 `harness/`，用户说"我的 harness-setup skill 更新了，帮这个旧项目补齐新的 harness 文件"
  - 操作：进入保守 update 模式 → 缺失文件才创建 → 已有 `feature_list.json` / `claude-progress.md` / `project-memory.md` 不覆盖 → `CLAUDE.md` / `AGENTS.md` 只追加缺失说明
  - 关键要点：重复运行必须幂等，不得清空项目状态或 memory

## 注意事项

- init.sh 的 `ROOT_DIR` 必须指向项目根目录（`SCRIPT_DIR/..`），绝对不能指向 harness 目录
- 模板脚本不得硬编码 Java/Node/Python 等运行时版本；需要显式覆盖时使用环境变量，否则优先从项目配置识别版本约束
- 初始化模式可以生成完整 harness；保守 update 模式只能补缺失文件，不得覆盖已有 harness 文件
- 如果 CLAUDE.md / AGENTS.md 已存在，不要整体覆盖；只做窄范围修正：路径引用和缺失的 memory / 必需文件说明
- 全局 `~/harness/user-memory.md` 已存在时绝对不能覆盖，必须保留用户已积累的偏好
- 保守 update 模式下，项目 `./harness/project-memory.md` 已存在时也不能覆盖；初始化模式下才从模板生成
- Memory 写入规则必须避免和 Claude Code auto-memory 对抗：用户要求“记住”“以后”“下次”或表达稳定偏好时，先写入对应的 harness memory；如果 auto-memory 也使用了，可以同步/镜像，但不得只写入 auto-memory；冲突时以 harness memory 为准
- feature_list.json 生成后 features 数组为空，让用户自己添加功能；update 模式不得清空已有 features
- 生成或补齐 init.sh 后必须 `chmod +x` 设置执行权限
- 生成或 update 后必须尽量运行 `./harness/init.sh` 验证脚本工作正常；失败时报告错误，不要隐藏失败
- update 模式结束时必须列出：新增文件、保留文件、追加说明、需人工对比的文件、验证结果
