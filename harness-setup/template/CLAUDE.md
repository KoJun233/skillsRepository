# CLAUDE.md

你正在一个为长时实现工作设计的仓库中工作。优先保证可靠完成、跨会话连续性和显式验证，而不是表面上的速度。

## 固定工作循环

每轮会话开始时：

1. 运行 `pwd`，确认当前在正确的仓库根目录
2. 读取 `harness/claude-progress.md`
3. 读取 `harness/feature_list.json`
4. 读取 `~/harness/user-memory.md`（全局用户偏好）和 `harness/project-memory.md`（项目偏好），遵守其中的代码规范与约定
5. 用 `git log --oneline -5` 查看最近提交
6. 运行 `./harness/init.sh`
7. 检查基础 smoke test 或端到端路径是否已经损坏

然后只选择一个未完成功能，围绕它工作，直到它被验证通过，或者被明确记录为 blocked。

## 规则

- 同一时间只能有一个 active feature
- 没有可运行证据时，不要声称完成
- 不要通过重写功能清单来隐藏未完成工作
- 不要为了"看起来完成"而删除或削弱测试
- 以仓库内文件作为唯一事实来源

## 必需文件

以下文件位于 `harness/` 目录下：

- `harness/feature_list.json`
- `harness/claude-progress.md`
- `harness/init.sh`
- `harness/session-handoff.md`（需要简短交接时使用）
- `harness/project-memory.md`（项目偏好，仅当前项目生效）

全局偏好文件（跨项目共享）：

- `~/harness/user-memory.md`（如存在则必须遵守）

## 记忆写入规则

当用户要求“记住”“以后”“下次”或表达稳定偏好时，先写入对应的 harness memory：跨项目偏好写入 `~/harness/user-memory.md`，当前项目偏好或约定写入 `harness/project-memory.md`。

如果 Claude Code auto-memory 也记录同一偏好，可以同步或镜像，但不得只写入 auto-memory。两边内容冲突时以 harness memory 为准。

## 完成门槛

只有在要求的验证成功且结果被记录后，功能状态才可以切换到 `passing`。

## 结束前

1. 更新进度日志
2. 更新功能状态
3. 记录仍然损坏或未验证的内容
4. 在仓库可安全恢复后提交
5. 给下一轮会话留下干净的重启路径
