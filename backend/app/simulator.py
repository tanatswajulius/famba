from time import sleep
from .store import update_job
from threading import Thread

STEPS = ["driver_assigned","enroute","arrived","riding","complete"]

def simulate(job_id: str):
    def run():
        for step in STEPS:
            sleep(2)               # 2s between steps for a smooth demo
            update_job(job_id, status=step)
    Thread(target=run, daemon=True).start()
