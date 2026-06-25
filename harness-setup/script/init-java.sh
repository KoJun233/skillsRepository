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

# 检查并设置 Java 环境
normalize_java_major() {
    local raw="${1:-}"
    raw="${raw#v}"
    raw="${raw%%-*}"
    if [[ "$raw" == 1.* ]]; then
        raw="${raw#1.}"
    fi
    raw="${raw%%.*}"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$raw"
    fi
}

read_xml_tag_value() {
    local tag="$1"
    local file="$2"
    sed -nE "s/.*<${tag}>[[:space:]]*([^<[:space:]]+)[[:space:]]*<\/${tag}>.*/\1/p" "$file" | head -1
}

detect_required_java_version() {
    REQUIRED_JAVA_VERSION_DETECTED=""
    REQUIRED_JAVA_VERSION_SOURCE=""

    if [[ -n "${REQUIRED_JAVA_VERSION:-}" ]]; then
        REQUIRED_JAVA_VERSION_DETECTED="$(normalize_java_major "$REQUIRED_JAVA_VERSION")"
        if [[ -z "$REQUIRED_JAVA_VERSION_DETECTED" ]]; then
            fail "REQUIRED_JAVA_VERSION 不是有效的 Java 主版本: $REQUIRED_JAVA_VERSION"
            exit 1
        fi
        REQUIRED_JAVA_VERSION_SOURCE="REQUIRED_JAVA_VERSION"
        return
    fi

    if [[ -f "pom.xml" ]]; then
        local value=""
        local tag=""
        for tag in maven.compiler.release maven.compiler.source maven.compiler.target java.version; do
            value="$(read_xml_tag_value "$tag" pom.xml || true)"
            if [[ -n "$value" ]]; then
                local normalized=""
                normalized="$(normalize_java_major "$value")"
                if [[ -n "$normalized" ]]; then
                    REQUIRED_JAVA_VERSION_DETECTED="$normalized"
                    REQUIRED_JAVA_VERSION_SOURCE="pom.xml <$tag>"
                    return
                fi
            fi
        done
    fi

    if [[ -f ".java-version" ]]; then
        local value=""
        value="$(normalize_java_major "$(head -1 .java-version)")"
        if [[ -n "$value" ]]; then
            REQUIRED_JAVA_VERSION_DETECTED="$value"
            REQUIRED_JAVA_VERSION_SOURCE=".java-version"
            return
        fi
    fi

    if [[ -f ".sdkmanrc" ]]; then
        local value=""
        value="$(sed -nE 's/^java=([0-9]+(\.[0-9]+)?).*/\1/p' .sdkmanrc | head -1)"
        if [[ -n "$value" ]]; then
            local normalized=""
            normalized="$(normalize_java_major "$value")"
            if [[ -n "$normalized" ]]; then
                REQUIRED_JAVA_VERSION_DETECTED="$normalized"
                REQUIRED_JAVA_VERSION_SOURCE=".sdkmanrc"
                return
            fi
        fi
    fi

    if [[ -f ".tool-versions" ]]; then
        local value=""
        value="$(sed -nE 's/^java[[:space:]]+([0-9]+(\.[0-9]+)?).*/\1/p' .tool-versions | head -1)"
        if [[ -n "$value" ]]; then
            local normalized=""
            normalized="$(normalize_java_major "$value")"
            if [[ -n "$normalized" ]]; then
                REQUIRED_JAVA_VERSION_DETECTED="$normalized"
                REQUIRED_JAVA_VERSION_SOURCE=".tool-versions"
                return
            fi
        fi
    fi
}

active_java_major() {
    local java_cmd="$1"
    local version_line=""
    version_line="$($java_cmd -version 2>&1 | head -1)"
    normalize_java_major "$(printf '%s\n' "$version_line" | cut -d'"' -f2)"
}

find_matching_jdk() {
    local required="$1"
    local jdk_path=""
    local search_roots=()

    if [[ -n "${HARNESS_JDK_SEARCH_PATHS:-}" ]]; then
        IFS=':' read -r -a search_roots <<< "$HARNESS_JDK_SEARCH_PATHS"
    else
        if [[ "$OSTYPE" == "darwin"* ]] && command -v /usr/libexec/java_home &> /dev/null; then
            if /usr/libexec/java_home -v "$required" &> /dev/null; then
                /usr/libexec/java_home -v "$required"
                return
            fi
        fi
        search_roots=(/usr/lib/jvm /opt/java)
    fi

    for root in "${search_roots[@]}"; do
        for jdk_path in "$root"/java-${required}* "$root"/jdk-${required}* "$root"/*-${required}*; do
            if [[ -x "$jdk_path/bin/java" && "$(active_java_major "$jdk_path/bin/java")" == "$required" ]]; then
                printf '%s\n' "$jdk_path"
                return
            fi
        done
    done
}

ensure_java_environment() {
    detect_required_java_version

    if [[ -n "$REQUIRED_JAVA_VERSION_DETECTED" ]]; then
        info "项目要求 Java 版本: $REQUIRED_JAVA_VERSION_DETECTED (来源: $REQUIRED_JAVA_VERSION_SOURCE)"
        local current_version=""
        if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
            current_version="$(active_java_major "$JAVA_HOME/bin/java")"
            if [[ "$current_version" == "$REQUIRED_JAVA_VERSION_DETECTED" ]]; then
                export PATH="$JAVA_HOME/bin:$PATH"
                ok "JAVA_HOME 已设置: $JAVA_HOME"
                ok "Java 版本: $current_version"
                return
            fi
            warn "JAVA_HOME 版本不匹配: $JAVA_HOME (Java ${current_version:-unknown})"
        fi

        local detected_home=""
        detected_home="$(find_matching_jdk "$REQUIRED_JAVA_VERSION_DETECTED")"
        if [[ -n "$detected_home" ]]; then
            export JAVA_HOME="$detected_home"
            export PATH="$JAVA_HOME/bin:$PATH"
            current_version="$(active_java_major "$JAVA_HOME/bin/java")"
            if [[ "$current_version" != "$REQUIRED_JAVA_VERSION_DETECTED" ]]; then
                fail "自动检测到的 JDK 版本不匹配: 需要 $REQUIRED_JAVA_VERSION_DETECTED, 当前 ${current_version:-unknown} ($JAVA_HOME)"
                exit 1
            fi
            ok "自动检测到 JDK $REQUIRED_JAVA_VERSION_DETECTED: $JAVA_HOME"
            ok "Java 版本: $current_version"
            return
        fi

        fail "未找到项目要求的 JDK $REQUIRED_JAVA_VERSION_DETECTED（来源: $REQUIRED_JAVA_VERSION_SOURCE），请安装对应 JDK 或设置 JAVA_HOME"
        exit 1
    fi

    warn "未从项目配置识别到 Java 版本，使用当前环境"
    if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
        export PATH="$JAVA_HOME/bin:$PATH"
        ok "JAVA_HOME 已设置: $JAVA_HOME"
        ok "Java 版本: $(active_java_major "$JAVA_HOME/bin/java")"
        return
    fi

    if ! command -v java &> /dev/null; then
        fail "未找到 Java，请安装 JDK 或设置 JAVA_HOME"
        exit 1
    fi
    ok "Java 版本: $(active_java_major java)"
}

ensure_java_environment
ok "Maven: $(mvn --version | head -1)"

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
