#!/usr/bin/env bash

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

info "当前目录: $PWD"

# 配置区
RUN_START="${RUN_START_COMMAND:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_VERIFY="${SKIP_VERIFY:-0}"

# ===== 阶段 0: 环境检查 =====
info "阶段 0/3: 环境检查"

if ! command -v node &> /dev/null; then
    fail "未找到 Node.js，请先安装 Node.js"
    exit 1
fi
ok "Node.js: $(node --version)"

if ! command -v npm &> /dev/null; then
    fail "未找到 npm"
    exit 1
fi
ok "npm: $(npm --version)"

ok "阶段 0 完成"
echo

# ===== 阶段 1: 构建 =====
if [[ "$SKIP_BUILD" == "1" ]]; then
    warn "跳过构建（SKIP_BUILD=1）"
else
    info "阶段 1/3: 安装依赖"
    if ! npm install; then
        fail "依赖安装失败"
        exit 1
    fi
    ok "阶段 1 完成"
fi
echo

# ===== 阶段 2: 验证 =====
if [[ "$SKIP_VERIFY" == "1" ]]; then
    warn "跳过验证（SKIP_VERIFY=1）"
else
    info "阶段 2/3: 运行测试"
    if ! npm test; then
        fail "测试失败"
        exit 1
    fi
    ok "阶段 2 完成"
fi
echo

# ===== 阶段 3: 启动 =====
info "启动命令:"
echo "    npm run dev"
echo

if [[ "$RUN_START" == "1" ]]; then
    info "阶段 3/3: 启动应用"
    exec npm run dev
else
    info "跳过启动（设置 RUN_START_COMMAND=1 以启动应用）"
fi

echo
ok "初始化完成"
