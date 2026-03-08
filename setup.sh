#!/bin/bash
set -e

echo "=== 1. 安装 pip 和基础工具 ==="
apt install -y python3-pip python3-dev gnupg curl wget xvfb

echo "=== 2. 安装 Chrome ==="
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt update
apt install -y google-chrome-stable

echo "=== 3. 安装 ChromeDriver ==="
CHROME_VER=$(google-chrome --version | grep -oP '\d+\.\d+\.\d+\.\d+')
echo "Chrome 版本: $CHROME_VER"
MAJOR=$(echo $CHROME_VER | cut -d. -f1)
# 从 ChromeDriver for Testing 获取匹配版本
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

echo "=== 4. 安装 Python 依赖 ==="
pip3 install selenium requests colorama ddddocr twocaptcha-python --break-system-packages

echo ""
echo "✅ 全部安装完成！"
echo "运行命令："
echo "  nohup xvfb-run -a -s \"-screen 0 1920x1080x24\" python3 aws.py > aws.log 2>&1 &"