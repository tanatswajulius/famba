from time import sleep
from threading import Thread
from .database import update_job, get_job

STEPS = ["driver_assigned", "enroute", "arrived", "riding", "complete"]


def simulate(job_id: str):
    def run():
        job = get_job(job_id)
        if not job:
            return

        driver = job.get("driver") or {}
        start_lat = driver.get("lat", job.get("pickup_lat"))
        start_lng = driver.get("lng", job.get("pickup_lng"))
        pickup_lat = job.get("pickup_lat")
        pickup_lng = job.get("pickup_lng")
        drop_lat = job.get("drop_lat")
        drop_lng = job.get("drop_lng")

        points = [
            (start_lat, start_lng),
            ((start_lat + pickup_lat) / 2, (start_lng + pickup_lng) / 2),
            (pickup_lat, pickup_lng),
            ((pickup_lat + drop_lat) / 2, (pickup_lng + drop_lng) / 2),
            (drop_lat, drop_lng),
        ]

        for step, coords in zip(STEPS, points):
            sleep(2)
            update_job(
                job_id,
                status=step,
                driver_lat=coords[0],
                driver_lng=coords[1],
            )

    Thread(target=run, daemon=True).start()
