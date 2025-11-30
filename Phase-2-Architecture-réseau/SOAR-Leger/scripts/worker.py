#!/usr/bin/env python3
"""
SOAR worker: super-debbugable version
"""
import os
import time
import json
import logging
import hashlib
from dotenv import load_dotenv
import redis
import requests
import urllib3
import traceback

# disable insecure https warnings when verify=False is used
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

load_dotenv()

# -------------------------
# Configuration (env + defaults)
# -------------------------
REDIS_HOST = os.getenv("REDIS_HOST", "127.0.0.1")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "123")
REDIS_LIST = os.getenv("REDIS_LIST", "so:alerts")
PROCESSING_LIST = os.getenv("REDIS_PROCESSING_LIST", REDIS_LIST + ":processing")
FAILED_LIST = os.getenv("REDIS_FAILED_LIST", REDIS_LIST + ":failed")
MAX_RETRIES = int(os.getenv("MAX_RETRIES", 5))
BASE_BACKOFF = float(os.getenv("BASE_BACKOFF", 2.0))  # seconds
N8N_WEBHOOK_URL = os.getenv(
    "N8N_WEBHOOK_URL",
    "https://10.0.254.4:5678/webhook/3a64f6b1-ff67-4b77-b032-e0a37406207d"
#     "https://10.0.254.4:5678/webhook-test/3a64f6b1-ff67-4b77-b032-e0a37406207d"
)
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", 10.0))
VERIFY_TLS = os.getenv("VERIFY_TLS", "false").lower() in ("1", "true", "yes")
DEBUG = os.getenv("DEBUG", "true").lower() in ("1", "true", "yes")

# -------------------------
# Logging
# -------------------------
logging.basicConfig(
    level=logging.DEBUG if DEBUG else logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

# -------------------------
# Helpers
# -------------------------
def sha1_of_item(item_str: str) -> str:
    return hashlib.sha1(item_str.encode("utf-8")).hexdigest()

def connect_redis():
    while True:
        try:
            client = redis.StrictRedis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                password=REDIS_PASSWORD,
                decode_responses=True,
                socket_timeout=5
            )
            client.ping()
            logging.info("Connected to Redis")
            return client
        except redis.exceptions.ResponseError as e:
            logging.error(f"Redis auth/response error: {e}; retrying in 5s")
            time.sleep(5)
        except Exception as e:
            logging.warning(f"Redis connection failed: {e}; retrying in 2s")
            time.sleep(2)

def recover_processing_list(r):
    moved = 0
    try:
        while True:
            item = r.rpop(PROCESSING_LIST)
            if item is None:
                break
            r.rpush(REDIS_LIST, item)
            moved += 1
            if DEBUG:
                logging.debug(f"Recovered item back to main list: {item}")
    except Exception as e:
        logging.warning(f"Failed to recover processing list: {e}")
    if moved:
        logging.info(f"Recovered {moved} item(s) from {PROCESSING_LIST} back to {REDIS_LIST}")

def send_to_n8n(alert_json):
    try:
        headers = {"Content-Type": "application/json"}
        logging.debug(f"Sending alert to n8n: {json.dumps(alert_json)}")
        resp = requests.post(
            N8N_WEBHOOK_URL,
            headers=headers,
            json=alert_json,
            timeout=REQUEST_TIMEOUT,
            verify=VERIFY_TLS
        )
    except requests.RequestException as e:
        logging.error(f"Request to n8n failed: {e}")
        logging.debug(traceback.format_exc())
        return False, str(e)

    status = resp.status_code
    logging.info(f"n8n responded: HTTP {status}, text: {resp.text[:200]}...")

    if status != 200:
        return False, resp.text

    try:
        obj = resp.json()
    except ValueError:
        logging.debug("n8n returned non-JSON but HTTP 200 -> accept as success")
        return True, resp.text

    ok_fields = False
    if isinstance(obj, dict):
        st = obj.get("status") or obj.get("result") or obj.get("message")
        if isinstance(st, str) and st.lower() in ("ok", "success", "applied"):
            ok_fields = True
        elif obj.get("applied") is True or obj.get("changed") is True or obj.get("success") is True:
            ok_fields = True

    return (ok_fields or status == 200), obj

def log_queue_status(r):
    try:
        main_len = r.llen(REDIS_LIST)
        processing_len = r.llen(PROCESSING_LIST)
        failed_len = r.llen(FAILED_LIST)
        logging.info(f"Queue status -> Main: {main_len}, Processing: {processing_len}, Failed: {failed_len}")
    except Exception as e:
        logging.warning(f"Failed to read queue lengths: {e}")

# -------------------------
# Main loop
# -------------------------
def main():
    r = connect_redis()
    recover_processing_list(r)
    logging.info("Starting main processing loop (one alert at a time).")

    last_status_log = time.time()

    while True:
        try:
            # ---------------------
            # Safe pop from Redis list
            # ---------------------
            try:
                item = r.brpoplpush(REDIS_LIST, PROCESSING_LIST, timeout=5)
            except redis.exceptions.TimeoutError:
                continue
            except Exception as e:
                logging.error(f"Redis brpoplpush failed: {e}")
                logging.debug(traceback.format_exc())
                time.sleep(1)
                continue

            if not item:
                continue

            logging.debug(f"Popped alert: {item[:200]}...")
            retry_key = f"retry:{sha1_of_item(item)}"

            # Parse JSON
            try:
                alert_json = json.loads(item)
            except json.JSONDecodeError:
                logging.error("Invalid JSON in queue; moving to failed list")
                r.lrem(PROCESSING_LIST, 1, item)
                r.rpush(FAILED_LIST, item)
                continue

            sig = alert_json.get("alert", {}).get("signature") or alert_json.get("alert", {}).get("signature_id") or "unknown"
            logging.info(f"Processing alert signature: {sig}")

            success, resp_obj = send_to_n8n(alert_json)

            if success:
                r.lrem(PROCESSING_LIST, 1, item)
                logging.info(f"Alert processed successfully. Removed from processing list.")
                try:
                    r.delete(retry_key)
                except Exception:
                    pass
                time.sleep(0.1)
            else:
                current_retries = 0
                try:
                    current_retries = r.incr(retry_key)
                    if current_retries == 1:
                        r.expire(retry_key, 3600)
                except Exception as e:
                    logging.warning(f"Failed to increment retry counter: {e}")
                    logging.debug(traceback.format_exc())

                logging.warning(f"n8n processing failed (attempt {current_retries}/{MAX_RETRIES}). Response: {resp_obj}")

                if current_retries >= MAX_RETRIES:
                    logging.error(f"Exceeded max retries ({MAX_RETRIES}). Moving item to failed list.")
                    r.lrem(PROCESSING_LIST, 1, item)
                    r.rpush(FAILED_LIST, item)
                    try:
                        r.delete(retry_key)
                    except Exception:
                        pass
                    continue

                backoff = BASE_BACKOFF * (2 ** (current_retries - 1))
                logging.info(f"Will requeue item after backoff {backoff:.1f}s")
                try:
                    r.rpush(REDIS_LIST, item)
                    r.lrem(PROCESSING_LIST, 1, item)
                except Exception as e:
                    logging.error(f"Failed to requeue item: {e}")
                    logging.debug(traceback.format_exc())
                time.sleep(backoff)

            # Periodic queue status log
            if time.time() - last_status_log > 10:  # every 10s
                log_queue_status(r)
                last_status_log = time.time()

        except redis.exceptions.ConnectionError:
            logging.warning("Lost connection to Redis — reconnecting...")
            r = connect_redis()
            recover_processing_list(r)
            time.sleep(1)
        except KeyboardInterrupt:
            logging.info("Worker stopped by user (KeyboardInterrupt)")
            break
        except Exception as e:
            logging.exception(f"Unhandled exception in main loop: {e}")
            time.sleep(2)

if __name__ == "__main__":
    main()
