import httpx
from decouple import config

SMR_URL = config("sourcemaps_reader")

if '%s' in SMR_URL:
    if config("SMR_KEY", default=None) is not None:
        SMR_URL = SMR_URL % config("SMR_KEY")
    else:
        SMR_URL = SMR_URL % "smr"


async def get_original_trace(key, positions, is_url=False):
    payload = {
        "key": key,
        "positions": positions,
        "padding": 5,
        "bucket": config('sourcemaps_bucket'),
        "isURL": is_url
    }
    try:
        async with httpx.AsyncClient() as client:
            r = await client.post(SMR_URL, json=payload, timeout=config("sourcemapTimeout", cast=int, default=5))
        if r.status_code != 200:
            print(f"Issue getting sourcemap status_code:{r.status_code}")
            return None
        return r.json()
    except Exception as e:
        print("Issue getting sourcemap")
        print(e)
        return None
