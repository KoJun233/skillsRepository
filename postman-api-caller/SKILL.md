---
name: postman-api-caller
description: 基于Postman Collection自动浏览、检索和调用API接口，支持环境变量管理与模板变量自动解析；当用户需要查询可用API、调用特定接口、设置接口环境变量或排查接口问题时使用
dependency:
  python:
    - requests>=2.28.0
---

# Postman API 调用器

## 任务目标
- 本 Skill 用于：通过 Postman API 浏览 Collection 中的接口并完成调用
- 能力包含：API 列表查询、API 详情获取、接口调用（自动解析模板变量）、环境变量更新
- 触发条件：用户询问有哪些 API、需要调用某个接口、需要设置 Cookie/Token 等环境变量、接口返回 Cookie 过期提示

## 前置准备
- 依赖：requests（Python HTTP 库）
- 凭证：需设置环境变量 `POSTMAN_API_KEY`，值为 Postman API Key（X-API-Key）
  - 获取方式：访问 https://web.postman.com/settings/me/api-keys ，登录后点击"Generate API Key"
  - 设置方式：`export POSTMAN_API_KEY=你的API密钥`
- 用户需提供 Postman Collection ID（从 Postman Collection URL 中获取，格式如 `30353504-8dff0f49-fee5-445c-bd8f-4ba58d799f42`）

## 操作步骤

### 标准流程：查找并调用 API

1. **获取 API 列表** — 列出 Collection 中所有 GET 接口
   - 脚本调用：`python scripts/list_apis.py --collection-id <COLLECTION_ID>`
   - 返回每个接口的 name、folderName、id
   - 若需查看完整详情加 `--detail` 参数

2. **定位目标 API** — 由智能体根据用户描述匹配接口名称和所属文件夹
   - 从返回列表中找到匹配的接口，记录其 id

3. **获取 API 详情** — 查看接口的完整参数信息
   - 脚本调用：`python scripts/get_api_detail.py --collection-id <COLLECTION_ID> --request-id <REQUEST_ID>`
   - 返回 url、headers、params（参数示例值在 description 中，value 为空待填充）

4. **确认参数** — 由智能体检查 params 列表，向用户确认每个必填参数的值
   - 若参数 description 含"例如"提示，参考其格式提供值
   - 若 headers 中含 `{{Cookie}}` 等模板变量，确认环境变量已设置

5. **调用 API** — 使用用户提供的参数值调用接口
   - 脚本调用：`python scripts/call_api.py --collection-id <COLLECTION_ID> --url "<URL>" --headers '<HEADERS_JSON>' --params '<PARAMS_JSON>'`
   - headers 格式：`[{"key":"Cookie","value":"{{Cookie}}"}]`
   - params 格式：`[{"key":"day","value":"60"},{"key":"verify","value":"xxx"}]`
   - 脚本自动解析 `{{变量名}}` 占位符，从 Collection 环境变量中替换
   - 若返回 Cookie 过期提示，引导用户重新设置环境变量

### 可选分支：更新环境变量

- 当需要更新 Cookie、Token 等环境变量时：
  - 脚本调用：`python scripts/update_variables.py --collection-id <COLLECTION_ID> --variables '<VARIABLES_JSON>'`
  - variables 格式：`[{"key":"Cookie","value":"sid=xxx; path=/"}]`
  - 更新后重新调用 API 即可

## 使用示例

- 示例1：
  - 场景/输入：用户问"有哪些可用的接口"
  - 预期产出：列出 Collection 中所有 GET 接口的名称、文件夹和 ID
  - 关键要点：仅需 collection-id 参数，首次使用需确认 Collection ID

- 示例2：
  - 场景/输入：用户说"帮我调用有成CRM同步接口，参数day=60，verify=lifeng202604081543"
  - 预期产出：先获取列表定位接口 → 获取详情确认参数 → 调用接口返回结果
  - 关键要点：需确认接口 ID、填入用户提供的参数值、检查 Cookie 等环境变量是否已配置

- 示例3：
  - 场景/输入：调用接口后返回"Cookie过期，请重新设置"
  - 预期产出：引导用户提供新 Cookie 值，通过 update_variables 脚本更新后重新调用
  - 关键要点：更新环境变量后无需重新获取 API 详情，直接重试 call_api 即可

## 资源索引
- 脚本：见 [scripts/list_apis.py](scripts/list_apis.py)（列出 Collection 中所有 GET API，参数：--collection-id, --detail）
- 脚本：见 [scripts/get_api_detail.py](scripts/get_api_detail.py)（获取指定 API 的详情，参数：--collection-id, --request-id）
- 脚本：见 [scripts/call_api.py](scripts/call_api.py)（调用 API 接口，自动解析模板变量，参数：--collection-id, --url, --headers, --params）
- 脚本：见 [scripts/update_variables.py](scripts/update_variables.py)（更新 Collection 环境变量，参数：--collection-id, --variables）

## 注意事项
- 首次使用需设置环境变量 `POSTMAN_API_KEY`，脚本通过该环境变量读取凭证
- Collection ID 从 Postman 网页版 Collection URL 中获取
- `{{变量名}}` 格式的模板变量由脚本自动从 Collection 环境变量中解析，无需手动替换
- call_api 仅支持 GET 请求；如需其他 HTTP 方法，需扩展脚本
- 接口返回 302 且 Location 含 sso 时表示登录态过期，需更新 Cookie 环境变量
