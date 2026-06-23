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
VENV_DIR=".venv"

# ===== 阶段 0: 环境检查 =====
info "阶段 0/3: 环境检查"

if ! command -v python3 &> /dev/null; then
    fail "未找到 Python 3"
    exit 1
fi
ok "Python: $(python3 --version)"

if [[ -d "$VENV_DIR" ]]; then
    source "$VENV_DIR/bin/activate"
    ok "虚拟环境已激活: $VENV_DIR"
else
    warn "未找到虚拟环境 ($VENV_DIR)，使用系统 Python"
fi

ok "阶段 0 完成"
echo

# ===== 阶段 1: 构建 =====
if [[ "$SKIP_BUILD" == "1" ]]; then
    warn "跳过构建（SKIP_BUILD=1）"
else
    info "阶段 1/3: 安装依赖"
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt
    elif [[ -f "pyproject.toml" ]]; then
        pip install -e .
    fi
    ok "阶段 1 完成"
fi
echo

# ===== 阶段 2: 验证 =====
if [[ "$SKIP_VERIFY" == "1" ]]; then
    warn "跳过验证（SKIP_VERIFY=1）"
else
    info "阶段 2/3: 运行测试"
    if ! python3 -m pytest; then
        fail "测试失败"
        exit 1
    fi
    ok "阶段 2 完成"
fi
echo

# ===== 阶段 3: 启动 =====
info "启动命令:"
echo "    python3 main.py"
echo

if [[ "$RUN_START" == "1" ]]; then
    info "阶段 3/3: 启动应用"
    exec python3 main.py
else
    info "跳过启动（设置 RUN_START_COMMAND=1 以启动应用）"
fi

echo
ok "初始化完成"
