#!/usr/bin/env python3
"""
Buoy LLM ROS 2 Action server – bridges Ollama and Whisper to ROS.
Exposes /llm/chat action for text, image, and audio (via Whisper) modalities.
Fairness: max 1 active goal per requester_id.
"""
import base64
import json
import os
import time
import urllib.error
import urllib.request
from collections import OrderedDict
from threading import Lock

import rclpy
from rclpy.action import ActionServer
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from std_msgs.msg import String

from llm_msgs.action import Chat


def _http_post_json(url: str, json_data: dict, timeout: float = 60) -> dict | None:
    data = json.dumps(json_data).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST", headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode()
            return json.loads(body) if body else {}
    except (urllib.error.URLError, OSError, json.JSONDecodeError):
        return None


def _http_post_audio(url: str, audio_bytes: bytes, timeout: float = 60) -> str | None:
    req = urllib.request.Request(url, data=audio_bytes, method="POST")
    req.add_header("Content-Type", "application/octet-stream")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8").strip()
    except (urllib.error.URLError, OSError):
        return None


class LLMNode(Node):
    def __init__(self):
        super().__init__("llm_node")
        self._lock = Lock()
        self._active: OrderedDict[str, object] = OrderedDict()  # requester_id -> goal_handle

        # ROS 2 parameters (env vars override defaults for Docker)
        self.declare_parameter("ollama_host", os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434"))
        self.declare_parameter("whisper_url", os.environ.get("WHISPER_URL", "http://127.0.0.1:9000/asr"))
        self.declare_parameter("model", os.environ.get("LLM_MODEL", "llava:7b"))
        self.declare_parameter("default_timeout_sec", float(os.environ.get("LLM_TIMEOUT_SEC", "30")))

        self._action_server = ActionServer(
            self,
            Chat,
            "chat",
            self._execute_callback,
        )
        # Status topic for topic graph visibility and dashboard
        qos = QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT, history=HistoryPolicy.KEEP_LAST, depth=1)
        self._status_pub = self.create_publisher(String, "status", qos)
        self._status_timer = self.create_timer(5.0, self._publish_status)
        self.get_logger().info("LLM Action server ready: /chat (llm_msgs/action/Chat)")

    def _publish_status(self):
        msg = String()
        msg.data = "ready"
        self._status_pub.publish(msg)

    def _execute_callback(self, goal_handle):
        goal = goal_handle.request
        requester_id = goal.requester_id or "unknown"
        modality = goal.modality or "text"
        prompt = goal.prompt or ""
        payload_b64 = goal.payload_base64 or ""
        timeout_sec = goal.timeout_sec if goal.timeout_sec > 0 else self.get_parameter("default_timeout_sec").value

        # Fairness: reject if requester already has active goal
        with self._lock:
            if requester_id in self._active:
                self.get_logger().warn(f"Rejecting goal from {requester_id} (already active)")
                result = Chat.Result()
                result.success = False
                result.error_message = "Already have an active request from this requester"
                goal_handle.abort(result)
                return result
            self._active[requester_id] = goal_handle

        result = Chat.Result()
        try:
            start = time.monotonic()
            text_prompt = prompt

            # Audio: transcribe first
            if modality == "audio" and payload_b64:
                goal_handle.publish_feedback(Chat.Feedback(status="transcribing", progress=0.0))
                whisper_url = self.get_parameter("whisper_url").value
                try:
                    audio_bytes = base64.b64decode(payload_b64)
                except Exception:
                    result.success = False
                    result.error_message = "Invalid base64 payload"
                    return result
                transcribed = _http_post_audio(whisper_url, audio_bytes, timeout=30)
                if transcribed:
                    text_prompt = f"{prompt}\n\n[Transcribed audio]: {transcribed}"
                else:
                    result.success = False
                    result.error_message = "Whisper transcription failed"
                    return result
                elapsed = time.monotonic() - start
                if elapsed > timeout_sec:
                    result.success = False
                    result.error_message = "Timeout during transcription"
                    return result

            goal_handle.publish_feedback(Chat.Feedback(status="generating", progress=0.1))

            # Call Ollama
            ollama_host = self.get_parameter("ollama_host").value
            model = self.get_parameter("model").value
            images = [payload_b64] if modality == "image" and payload_b64 else None
            messages = [{"role": "user", "content": text_prompt}]
            payload = {"model": model, "messages": messages, "stream": False}
            if images:
                payload["images"] = images

            remaining = timeout_sec - (time.monotonic() - start)
            out = _http_post_json(f"{ollama_host}/api/chat", payload, timeout=max(10.0, remaining))

            if not out or "message" not in out:
                result.success = False
                result.error_message = "Ollama request failed"
                return result

            msg = out["message"]
            content = msg.get("content", "").strip() if isinstance(msg, dict) else str(msg).strip()
            result.content = content
            result.success = True
            result.error_message = ""
            goal_handle.succeed()
            return result

        except Exception as e:
            result.success = False
            result.error_message = str(e)
            goal_handle.abort(result)
            return result
        finally:
            with self._lock:
                self._active.pop(requester_id, None)


def main(args=None):
    rclpy.init(args=args)
    node = LLMNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
