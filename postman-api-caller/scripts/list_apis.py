import os
import argparse
import json
import requests


def get_credential():
    credential = os.getenv("POSTMAN_API_KEY")
    if not credential:
        raise ValueError("缺少Postman API凭证，请设置环境变量 POSTMAN_API_KEY")
    return credential


def list_apis(collection_id, is_detail=False):
    """获取Postman Collection中所有GET接口列表"""
    api_key = get_credential()
    url = f"https://api.getpostman.com/collections/{collection_id}"
    headers = {"X-API-Key": api_key}

    try:
        response = requests.get(url, headers=headers, timeout=30)
        if response.status_code != 200:
            raise Exception(f"请求Postman API失败: HTTP {response.status_code}, {response.text}")

        data = response.json()
        collection = data.get("collection", {})
        items_raw = collection.get("item", [])

        # 解析文件夹和接口
        result = []
        for folder in items_raw:
            folder_name = folder.get("name", "")
            for item in folder.get("item", []):
                request = item.get("request", {})
                method = request.get("method", "")
                if method != "GET":
                    continue
                if is_detail:
                    # 完整详情
                    url_obj = request.get("url", {})
                    if isinstance(url_obj, str):
                        url_obj = {"raw": url_obj}
                    header_list = request.get("header", [])
                    query_list = url_obj.get("query", [])
                    result.append({
                        "name": item.get("name", ""),
                        "folderName": folder_name,
                        "id": item.get("id", ""),
                        "method": method,
                        "url": url_obj.get("raw", ""),
                        "headers": header_list,
                        "params": query_list
                    })
                else:
                    # 简要信息
                    result.append({
                        "name": item.get("name", ""),
                        "folderName": folder_name,
                        "id": item.get("id", "")
                    })

        return result

    except requests.exceptions.RequestException as e:
        raise Exception(f"请求失败: {str(e)}")


def main():
    parser = argparse.ArgumentParser(description="获取Postman Collection中的API列表")
    parser.add_argument("--collection-id", required=True, help="Postman Collection ID")
    parser.add_argument("--detail", action="store_true", default=False,
                        help="是否返回完整详情，默认仅返回名称和ID")
    args = parser.parse_args()

    try:
        result = list_apis(args.collection_id, is_detail=args.detail)
        print(json.dumps({"status": "success", "data": result}, ensure_ascii=False, indent=2))
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
