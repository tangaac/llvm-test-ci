import schedule
import time
import subprocess
import os

def run_ci():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ci_script = os.path.join(script_dir, "ci.sh")
    subprocess.run(["sh", ci_script])

# 设置每天00:05执行
schedule.every().day.at("00:05").do(run_ci)

while True:
    schedule.run_pending()
    time.sleep(36000)  # 每10h检查一次
