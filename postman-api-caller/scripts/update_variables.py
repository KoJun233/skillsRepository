import os
import argparse
import json
import requests


def get_credential():
    credential = os.getenv("POSTMAN_API_KEY")
    if not credential:
        raise ValueError("缺少Postman API凭证，请设置环境变量 POSTMAN_API_KEY")
    return credential


def update_variables(collection_id, variables_json):
    """更新/新增Postman Collection的环境变量"""
    api_key = get_credential()

    # 获取当前变量
    url = f"https://api.getpostman.com/collections/{collection_id}"
    headers = {"X-API-Key": api_key}

    try:
        response = requests.get(url, headers=headers, timeout=30)
        if response.status_code != 200:
            raise Exception(f"获取Collection失败: HTTP {response.status_code}, {response.text}")

        collection = response.json().get("collection", {})
        existing_vars = collection.get("variable", [])

        # 构建变量Map，以key去重
        var_map = {}
        for v in existing_vars:
            var_map[v.get("key", "")] = v

        # 合并新变量
        new_vars = json.loads(variables_json)
        for v in new_vars:
            var_map[v.get("key", "")] = v

        # 构建PATCH请求体
        patch_body = {
            "collection": {
                "variable": list(var_map.values())
            }
        }

        # 发送PATCH请求更新变量
        patch_url = f"https://api.getpostman.com/collections/{collection_id}"
        patch_headers = {
            "X-API-Key": api_key,
            "Content-Type": "application/json"
        }
        patch_response = requests.patch(patch_url, headers=patch_headers, json=patch_body, timeout=30)

        if patch_response.status_code != 200:
            raise Exception(f"更新变量失败: HTTP {patch_response.status_code}, {patch_response.text}")

        return {
            "updated_count": len(new_vars),
            "total_count": len(var_map),
            "variables": list(var_map.values())
        }

    except requests.exceptions.RequestException as e:
        raise Exception(f"请求失败: {str(e)}")


def main():
    parser = argparse.ArgumentParser(description="更新/新增Postman Collection的环境变量")
    parser.add_argument("--collection-id", required=True, help="Postman Collection ID")
    parser.add_argument("--variables", required=True,
                        help="变量JSON数组，格式: [{\"key\":\"Cookie\",\"value\":\"sid=xxx\"}]")
    args = parser.parse_args()

    try:
        result = update_variables(args.collection_id, args.variables)
        print(json.dumps({"status": "success", "data": result}, ensure_ascii=False, indent=2))
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
