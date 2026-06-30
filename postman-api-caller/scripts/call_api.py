import os
import re
import argparse
import json
import requests


def get_credential():
    credential = os.getenv("POSTMAN_API_KEY")
    if not credential:
        raise ValueError("缺少Postman API凭证，请设置环境变量 POSTMAN_API_KEY")
    return credential


def fetch_collection_variables(collection_id, api_key):
    """从Collection中获取所有环境变量"""
    url = f"https://api.getpostman.com/collections/{collection_id}"
    headers = {"X-API-Key": api_key}
    response = requests.get(url, headers=headers, timeout=30)
    if response.status_code != 200:
        raise Exception(f"获取Collection失败: HTTP {response.status_code}")
    collection = response.json().get("collection", {})
    variables = collection.get("variable", [])
    var_map = {}
    for v in variables:
        key = v.get("key", "")
        value = v.get("value", "")
        if key and value:
            var_map[key] = value
    return var_map


def resolve_template_variables(text, variable_map):
    """解析 {{variable}} 格式的模板变量"""
    pattern = r"\{\{\s*([\s\S]*?)\s*}}"

    def replacer(match):
        var_name = match.group(1).strip()
        if var_name in variable_map:
            return variable_map[var_name]
        return match.group(0)  # 未找到变量则保留原值

    return re.sub(pattern, replacer, text)


def call_api(collection_id, url, headers_json, params_json):
    """调用API接口，自动解析模板变量"""
    api_key = get_credential()

    # 获取Collection变量用于解析模板占位符
    variable_map = fetch_collection_variables(collection_id, api_key)

    # 清理URL（去除query string，参数通过params传递）
    clean_url = url.split("?")[0]

    # 解析headers
    try:
        header_list = json.loads(headers_json) if headers_json else []
    except json.JSONDecodeError:
        return {"status": "error", "message": "headers参数JSON解析失败"}

    # 解析params
    try:
        param_list = json.loads(params_json) if params_json else []
    except json.JSONDecodeError:
        return {"status": "error", "message": "params参数JSON解析失败"}

    # 构建请求头，解析模板变量
    req_headers = {}
    unresolved = []
    for h in header_list:
        key = h.get("key", "")
        value = h.get("value", "")
        if re.search(r"\{\{\s*[\s\S]*?\s*}}", value):
            var_name = re.search(r"\{\{\s*([\s\S]*?)\s*}}", value).group(1).strip()
            if var_name in variable_map:
                value = variable_map[var_name]
            else:
                unresolved.append(var_name)
                continue
        if key and value:
            req_headers[key] = value

    if unresolved:
        return {
            "status": "error",
            "message": f"请求头变量未定义: {', '.join(unresolved)}，请通过update_variables脚本设置或让用户手动提供"
        }

    # 构建请求参数
    req_params = {}
    missing_params = []
    for p in param_list:
        key = p.get("key", "")
        value = p.get("value", "")
        if key:
            if not value:
                desc = p.get("description", "")
                missing_params.append(f"{key}({desc})")
            else:
                req_params[key] = value

    if missing_params:
        return {
            "status": "error",
            "message": f"以下参数未提供值: {', '.join(missing_params)}，请让用户提供后再调用"
        }

    # 发起GET请求
    try:
        response = requests.get(clean_url, headers=req_headers, params=req_params, timeout=500, allow_redirects=False)

        if response.status_code == 302:
            location = response.headers.get("Location", "")
            if "sso" in location:
                return {
                    "status": "error",
                    "message": "Cookie过期，请重新设置环境变量中的Cookie值"
                }

        return {
            "status": "success",
            "http_code": response.status_code,
            "data": response.text
        }

    except requests.exceptions.RequestException as e:
        return {"status": "error", "message": f"请求失败: {str(e)}"}


def main():
    parser = argparse.ArgumentParser(description="调用Postman Collection中配置的API接口")
    parser.add_argument("--collection-id", required=True, help="Postman Collection ID")
    parser.add_argument("--url", required=True, help="API请求URL")
    parser.add_argument("--headers", default="[]", help="请求头JSON数组，格式: [{\"key\":\"Cookie\",\"value\":\"{{Cookie}}\"}]")
    parser.add_argument("--params", default="[]", help="查询参数JSON数组，格式: [{\"key\":\"day\",\"value\":\"60\"}]")
    args = parser.parse_args()

    result = call_api(args.collection_id, args.url, args.headers, args.params)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
