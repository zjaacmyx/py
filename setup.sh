#!/bin/bash
set -e

echo "=== 1. 安装系统基础工具 ==="
apt update
apt install -y python3 python3-pip python3-dev gnupg curl wget xvfb git \
    libzbar0 libzbar-dev unzip ca-certificates

echo "=== 2. 强制解除 pip 系统限制 ==="
PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
EM_FILE="/usr/lib/python${PY_VER}/EXTERNALLY-MANAGED"
if [ -f "$EM_FILE" ]; then
    rm -f "$EM_FILE"
    echo "已删除 $EM_FILE"
fi

echo "=== 3. 升级 pip ==="
python3 -m pip install --upgrade pip --ignore-installed || true

echo "=== 4. 安装 Chrome ==="
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | \
    gpg --yes --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list
apt update
apt install -y google-chrome-stable

echo "=== 5. 安装 ChromeDriver ==="
CHROME_VER=$(google-chrome --version | grep -oP '\d+\.\d+\.\d+\.\d+')
echo "Chrome 版本: $CHROME_VER"
MAJOR=$(echo $CHROME_VER | cut -d. -f1)
DRIVER_URL=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | python3 -c "
import json,sys
data=json.load(sys.stdin)
major='$MAJOR'
for v in reversed(data['versions']):
    if v['version'].split('.')[0]==major:
        for d in v.get('downloads',{}).get('chromedriver',[]):
            if d['platform']=='linux64':
                print(d['url'])
                exit()
")
echo "ChromeDriver URL: $DRIVER_URL"
wget -q "$DRIVER_URL" -O /tmp/chromedriver.zip
unzip -o /tmp/chromedriver.zip -d /tmp/
find /tmp -name "chromedriver" -type f | xargs -I{} cp {} /usr/local/bin/chromedriver
chmod +x /usr/local/bin/chromedriver
echo "ChromeDriver 版本: $(chromedriver --version)"

echo "=== 6. 安装 Python 依赖 ==="
python3 -m pip install --ignore-installed \
    selenium \
    requests \
    colorama \
    git+https://github.com/sml2h3/ddddocr.git \
    twocaptcha-python \
    pyotp \
    pyzbar \
    pypinyin \
    pillow \
    opencv-python-headless \
    numpy \
    boto3 \
    botocore \
    paramiko \
    PySocks \
    webdriver-manager

echo "=== 7. 验证所有模块 ==="
# 关闭 set -e，验证失败只警告不退出
set +e
python3 << 'PYEOF'
failed = []
modules = {
    "pyotp":     "import pyotp",
    "pyzbar":    "from pyzbar.pyzbar import decode",
    "pypinyin":  "import pypinyin",
    "boto3":     "import boto3",
    "selenium":  "from selenium import webdriver",
    "ddddocr":   "import ddddocr; ddddocr.DdddOcr(show_ad=False)",
    "paramiko":  "import paramiko",
    "requests":  "import requests",
    "colorama":  "import colorama",
    "cv2":       "import cv2",
    "numpy":     "import numpy",
}
for name, stmt in modules.items():
    try:
        exec(stmt)
        print(f"  ✅ {name}")
    except Exception as e:
        print(f"  ❌ {name}: {e}")
        failed.append(name)
if failed:
    print(f"\n⚠️  有问题的模块: {failed}")
    print("提示: 可手动运行 python3 -m pip install <模块名> --ignore-installed")
else:
    print("\n✅ 所有模块验证通过")
PYEOF
set -e

echo ""
echo "============================================"
echo "✅ 安装完成！"
echo "============================================"
echo ""
echo "前台运行:"
echo "  xvfb-run -a -s \"-screen 0 1920x1080x24\" python3 aws.py"
echo ""
echo "后台运行:"
echo "  nohup xvfb-run -a -s \"-screen 0 1920x1080x24\" python3 aws.py > aws.log 2>&1 &"
echo ""
echo "查看日志:  tail -f aws.log"
echo "停止运行:  pkill -f aws.py"
echo "============================================"
