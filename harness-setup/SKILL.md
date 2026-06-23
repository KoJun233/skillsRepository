---
name: harness-setup
description: 为项目搭建长时运行的 coding agent 工作流框架（harness）。当用户说"搭建 harness"、"配置 agent 工作流"、"设置长时运行工作流"、"初始化 coding agent 环境"、"设置跨会话连续工作"时触发。自动生成 init.sh、feature_list.json、claude-progress.md、session-handoff.md、CLAUDE.md、AGENTS.md 等模板文件，支持 Java/Maven、Node.js、Python 项目。
---

# Harness 工作流搭建

## 任务目标

- 本 Skill 用于：为新项目快速搭建 harness 工作流框架，实现长时运行、跨会话连续的 coding agent 工作流
- 能力包含：
  - 自动检测项目类型（Java/Maven、Node.js、Python）
  - 从模板库生成 init.sh 脚本
  - 从模板库生成所有 harness 文件
- 触发条件：用户提到"搭建 harness"、"配置 agent 工作流"等关键词

## 前置准备

- 项目根目录已存在

## 资源索引

### 脚本文件（`script/` 目录）

| 文件 | 项目类型 | 说明 |
|------|----------|------|
| `script/init-java.sh` | Java/Maven | 含 JDK 21 自动检测、Maven 构建、Profile 切换 |
| `script/init-node.sh` | Node.js | 含 Node/npm 检查、npm install/test/dev |
| `script/init-python.sh` | Python | 含虚拟环境、pip/pytest、python3 启动 |

### 模板文件（`template/` 目录）

| 文件 | 用途 | 占位符 |
|------|------|--------|
| `template/feature_list.json` | 功能状态清单 | `{{PROJECT_NAME}}` `{{DATE}}` |
| `template/claude-progress.md` | 会话进度日志 | `{{PROJECT_ROOT}}` `{{VERIFY_COMMAND}}` `{{PROJECT_TYPE}}` `{{BUILD_TOOL}}` `{{DATE}}` |
| `template/session-handoff.md` | 会话交接摘要 | `{{VERIFY_COMMAND}}` `{{DEBUG_COMMANDS}}` |
| `template/CLAUDE.md` | 主 Claude 会话指令 | 无（可直接复制） |
| `template/AGENTS.md` | 多 agent 工作流规则 | 无（可直接复制） |

## 操作步骤

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

### 步骤 5：生成 CLAUDE.md 和 AGENTS.md

- 如果目标项目**不存在**这两个文件：从 `template/` 目录直接复制
- 如果目标项目**已存在**这两个文件：只检查路径引用是否正确（必须是 `./harness/init.sh` 而非 `./init.sh`），不覆盖已有内容

### 步骤 6：验证

运行 `./harness/init.sh` 验证脚本工作正常。

## 使用示例

- 示例 1：
  - 场景：用户在新 Java 项目中说"帮我搭建 harness 工作流"
  - 操作：检测到 `pom.xml` → 复制 `script/init-java.sh` → 复制模板文件并替换占位符 → 运行验证
  - 预期产出：完整的 harness 框架
  - 关键要点：自动检测 JDK 版本，检查 Maven 是否可用

- 示例 2：
  - 场景：用户说"配置 agent 工作流，这是一个 Node.js 项目"
  - 操作：复制 `script/init-node.sh` → 复制模板文件 → 运行验证
  - 预期产出：完整的 harness 框架，init.sh 使用 npm 命令

- 示例 3：
  - 场景：项目已有 CLAUDE.md，用户说"初始化 coding agent 环境"
  - 操作：只更新路径引用，不覆盖已有内容
  - 关键要点：已存在的文件只修不改

## 注意事项

- init.sh 的 `ROOT_DIR` 必须指向项目根目录（`SCRIPT_DIR/..`），绝对不能指向 harness 目录
- 如果 CLAUDE.md / AGENTS.md 已存在，只修改路径引用，不覆盖内容
- feature_list.json 生成后 features 数组为空，让用户自己添加功能
- 生成后必须运行 `./harness/init.sh` 验证脚本工作正常
- init.sh 生成后必须 `chmod +x` 设置执行权限
