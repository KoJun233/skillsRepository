import os
import argparse
import json
import requests


def get_credential():
    credential = os.getenv("POSTMAN_API_KEY")
    if not credential:
        raise ValueError("缺少Postman API凭证，请设置环境变量 POSTMAN_API_KEY")
    return credential


def get_api_detail(collection_id, request_id):
    """获取指定API请求的详细信息"""
    api_key = get_credential()
    url = f"https://api.getpostman.com/collections/{collection_id}/requests/{request_id}"
    headers = {"X-API-Key": api_key}

    try:
        response = requests.get(url, headers=headers, timeout=30)
        if response.status_code != 200:
            raise Exception(f"请求Postman API失败: HTTP {response.status_code}, {response.text}")

        data = response.json().get("data", {})

        # 提取关键字段
        url_obj = data.get("url", {})
        if isinstance(url_obj, str):
            url_obj = {"raw": url_obj}

        header_list = data.get("headerData", data.get("header", []))
        query_list = data.get("queryParams", url_obj.get("query", []))

        # 处理参数：将示例值移到description中，清空value
        processed_params = []
        for param in query_list:
            value = param.get("value", "")
            desc = param.get("description", "") or ""
            if value:
                desc = (desc + ", 例如：" + value) if desc else "例如：" + value
            processed_params.append({
                "key": param.get("key", ""),
                "value": "",
                "description": desc
            })

        result = {
            "name": data.get("name", ""),
            "method": data.get("method", ""),
            "url": url_obj.get("raw", ""),
            "headers": header_list,
            "params": processed_params
        }

        return result

    except requests.exceptions.RequestException as e:
        raise Exception(f"请求失败: {str(e)}")


def main():
    parser = argparse.ArgumentParser(description="获取Postman Collection中指定API的详细信息")
    parser.add_argument("--collection-id", required=True, help="Postman Collection ID")
    parser.add_argument("--request-id", required=True, help="API请求ID")
    args = parser.parse_args()

    try:
        result = get_api_detail(args.collection_id, args.request_id)
        print(json.dumps({"status": "success", "data": result}, ensure_ascii=False, indent=2))
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
