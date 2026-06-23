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
PROFILE="${PROFILE:-dev}"
RUN_START="${RUN_START_COMMAND:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_VERIFY="${SKIP_VERIFY:-0}"
MVN_OPTS=(--batch-mode --fail-at-end -P "$PROFILE")

# ===== 阶段 0: 环境检查 =====
info "阶段 0/3: 环境检查"

if ! command -v mvn &> /dev/null; then
    fail "未找到 Maven，请先安装 Maven 3.x"
    exit 1
fi
ok "Maven: $(mvn --version | head -1)"

# 检查并设置 JAVA_HOME
need_detect_jdk=false
if [[ -z "${JAVA_HOME:-}" ]]; then
    info "JAVA_HOME 未设置，尝试自动检测 JDK 21..."
    need_detect_jdk=true
else
    java_version="$("$JAVA_HOME/bin/java" -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)"
    if [[ "$java_version" != "21" ]]; then
        warn "JAVA_HOME 已设置但版本不匹配: $JAVA_HOME (Java $java_version)"
        info "尝试自动检测 JDK 21..."
        need_detect_jdk=true
    else
        ok "JAVA_HOME 已设置: $JAVA_HOME"
    fi
fi

if [[ "$need_detect_jdk" == true ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if /usr/libexec/java_home -v 21 &> /dev/null; then
            export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
            ok "自动检测到 JDK 21: $JAVA_HOME"
        else
            fail "未找到 JDK 21，请安装 JDK 21 或手动设置 JAVA_HOME"
            exit 1
        fi
    else
        for jdk_path in /usr/lib/jvm/java-21-openjdk-* /usr/lib/jvm/java-21-oracle-* /opt/java/jdk-21*; do
            if [[ -x "$jdk_path/bin/java" ]]; then
                export JAVA_HOME="$jdk_path"
                ok "自动检测到 JDK 21: $JAVA_HOME"
                break
            fi
        done
        if [[ -z "${JAVA_HOME:-}" ]]; then
            fail "未找到 JDK 21，请安装 JDK 21 或手动设置 JAVA_HOME"
            exit 1
        fi
    fi
fi

java_version="$("$JAVA_HOME/bin/java" -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)"
if [[ "$java_version" != "21" ]]; then
    fail "Java 版本不匹配: 需要 21, 当前 $java_version"
    exit 1
fi
ok "Java 版本: $java_version"

ok "阶段 0 完成"
echo

# ===== 阶段 1: 构建 =====
if [[ "$SKIP_BUILD" == "1" ]]; then
    warn "跳过构建（SKIP_BUILD=1）"
else
    info "阶段 1/3: 构建项目"
    info "执行: mvn clean install -DskipTests ${MVN_OPTS[*]}"
    if ! mvn clean install -DskipTests "${MVN_OPTS[@]}"; then
        fail "构建失败"
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
    info "执行: mvn test ${MVN_OPTS[*]}"
    if ! mvn test "${MVN_OPTS[@]}"; then
        fail "测试失败"
        exit 1
    fi
    ok "阶段 2 完成"
fi
echo

# ===== 阶段 3: 启动 =====
info "启动命令:"
echo "    mvn spring-boot:run ${MVN_OPTS[*]} -Dspring.profiles.active=$PROFILE"
echo

if [[ "$RUN_START" == "1" ]]; then
    info "阶段 3/3: 启动应用"
    exec mvn spring-boot:run "${MVN_OPTS[@]}" -Dspring.profiles.active="$PROFILE"
else
    info "跳过启动（设置 RUN_START_COMMAND=1 以启动应用）"
fi

echo
ok "初始化完成"
