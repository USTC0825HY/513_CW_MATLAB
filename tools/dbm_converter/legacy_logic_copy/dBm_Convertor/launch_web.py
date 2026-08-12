"""启动本地网页应用，并自动在默认浏览器中打开。"""

from __future__ import annotations

import http.server
import os
from pathlib import Path
import socketserver
import threading
import webbrowser


WEB_DIR = Path(__file__).resolve().parent / "web"


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main() -> None:
    os.chdir(WEB_DIR)
    handler = http.server.SimpleHTTPRequestHandler
    with ReusableTCPServer(("127.0.0.1", 0), handler) as server:
        host, port = server.server_address
        url = f"http://{host}:{port}/"
        print(f"本地换算器已启动：{url}")
        print("关闭此窗口或按 Ctrl+C 即可停止。")
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\n本地换算器已停止。")


if __name__ == "__main__":
    main()
