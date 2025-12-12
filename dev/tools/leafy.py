#!/usr/bin/env python3
"""
leafy.py

Stream `docker logs -f <container>` either locally or from a remote host over SSH,
and pretty-print JSON log lines.

This version supports forcing ANSI color output:
  - CLI: --force-color
  - Env: FORCE_COLOR=1 or CLICOLOR_FORCE=1

Examples:
  python3 leafy.py --container my-container
  FORCE_COLOR=1 python3 leafy.py --container my-container | tee out.log
  python3 leafy.py --force-color --remote user@host --container my-container
"""

import argparse
import json
import subprocess
import sys
import shutil
import textwrap
import time
import os
from datetime import datetime, timezone

try:
    from zoneinfo import ZoneInfo
except Exception:
    ZoneInfo = None

INDENT = " " * 4
WRAP_WIDTH = 110

def parse_args():
    p = argparse.ArgumentParser(description="Pretty-print JSON Docker logs (local or remote via ssh)")
    p.add_argument("--container", "-c", help="docker container name (required unless --stdin)")
    p.add_argument("--stdin", action="store_true", help="read logs from stdin instead of running docker/ssh")
    p.add_argument("--docker-args", default="", help="extra args to pass to `docker logs -f`, e.g. '--since=1m --tail=200'")
    p.add_argument("--tz", default="America/New_York", help="timezone used for display (default: America/New_York)")
    p.add_argument("--remote", "-r", help="user@host to SSH to (if omitted run docker locally)")
    p.add_argument("--ssh-port", type=int, default=22, help="ssh port (default 22)")
    p.add_argument("--ssh-key", help="path to private key to use for ssh (optional)")
    p.add_argument("--use-sudo", action="store_true", help="prefix docker command with sudo on remote host")
    p.add_argument("--ssh-args", default="", help="extra args to pass to ssh (e.g. '-o StrictHostKeyChecking=no')")
    p.add_argument("--retries", type=int, default=5, help="reconnection attempts when SSH drops (default 5)")
    p.add_argument("--retry-backoff", type=float, default=2.0, help="base backoff seconds (exponential) between retries")
    # Color forcing
    p.add_argument("--force-color", action="store_true", help="force ANSI color output even if stdout is not a TTY")
    return p.parse_args()

def env_force_color():
    v = os.environ.get("FORCE_COLOR") or os.environ.get("CLICOLOR_FORCE")
    if v is None:
        return False
    return v.lower() in ("1", "true", "yes", "on")

def supports_color(forced: bool) -> bool:
    # If forced via CLI or env, return True
    if forced or env_force_color():
        return True
    # otherwise return True only if stdout is a tty
    return sys.stdout.isatty()

# Initialize color constants based on whether colors are enabled.
def init_colors(enable: bool):
    global RED, YEL, GRN, BLU, MAG, DIM, RESET
    if not enable:
        RED = YEL = GRN = BLU = MAG = DIM = RESET = ""
        return

    # Try to use colorama for consistent behavior on mac/windows.
    try:
        import colorama
        # If colors are forced, don't strip them; otherwise let colorama decide.
        # colorama.init(strip=not enable) => strip=False when enable==True
        colorama.init(strip=False)
        RED = colorama.Fore.RED + colorama.Style.BRIGHT
        YEL = colorama.Fore.YELLOW + colorama.Style.BRIGHT
        GRN = colorama.Fore.GREEN + colorama.Style.BRIGHT
        BLU = colorama.Fore.CYAN + colorama.Style.BRIGHT
        MAG = colorama.Fore.MAGENTA + colorama.Style.BRIGHT
        DIM = colorama.Style.DIM
        RESET = colorama.Style.RESET_ALL
    except Exception:
        # Fallback to raw ANSI sequences
        RED = "\x1b[31;1m"
        YEL = "\x1b[33;1m"
        GRN = "\x1b[32;1m"
        BLU = "\x1b[36;1m"
        MAG = "\x1b[35;1m"
        DIM = "\x1b[2m"
        RESET = "\x1b[0m"

def iso_to_display(ts_iso, tz_name):
    if not ts_iso:
        return ""
    try:
        dt = datetime.fromisoformat(ts_iso)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if ZoneInfo:
            tz = ZoneInfo(tz_name)
            local = dt.astimezone(tz)
            return local.strftime("%Y-%m-%d %H:%M:%S %Z")
        else:
            return dt.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    except Exception:
        return ts_iso

def safe_json_load(line):
    try:
        return json.loads(line)
    except Exception:
        try:
            s = line.find("{")
            e = line.rfind("}")
            if s != -1 and e != -1:
                return json.loads(line[s:e+1])
        except Exception:
            return None
    return None

def pretty_print_log(obj, tz_name):
    ts = obj.get("Timestamp") or obj.get("time") or obj.get("@timestamp")
    level = obj.get("Level") or obj.get("level") or obj.get("severity") or ""
    source = obj.get("SourceContext") or obj.get("logger") or obj.get("source") or ""
    message_template = obj.get("MessageTemplate") or obj.get("message") or obj.get("msg") or ""
    props = obj.get("Properties") or obj.get("properties") or {}

    tdisp = iso_to_display(ts, tz_name)
    level_label = (level.upper() if isinstance(level, str) else str(level))
    level_color = {
        "ERROR": RED,
        "ERR": RED,
        "WARNING": YEL,
        "WARN": YEL,
        "INFO": GRN,
        "DEBUG": BLU,
    }.get(level_label, MAG)

    header = f"[{tdisp}] {level_color}{level_label}{RESET}"
    if source:
        header += f" {DIM}({source}){RESET}"
    print(header)

    if message_template:
        msg = message_template
        try:
            for k, v in list(props.items()):
                if isinstance(v, (dict, list)):
                    continue
                token = "{" + str(k) + "}"
                if token in msg:
                    msg = msg.replace(token, str(v))
        except Exception:
            pass

        if isinstance(msg, str):
            msg = msg.replace("\\n", "\n")
        for line in str(msg).splitlines():
            for w in textwrap.wrap(line, width=WRAP_WIDTH):
                print(INDENT + w)

    simple_keys = ["RequestPath", "RequestId", "User", "ActionName", "ConnectionId", "SessionId", "ActionId"]
    meta_parts = []
    for k in simple_keys:
        v = props.get(k)
        if v:
            meta_parts.append(f"{k}={v}")
    if meta_parts:
        print(INDENT + DIM + " | ".join(meta_parts) + RESET)

    error_val = props.get("Error") or props.get("error") or props.get("stack") or None
    other_keys = [k for k in props.keys() if k not in simple_keys + ["Error", "error", "stack"]]
    if other_keys:
        for k in other_keys:
            v = props.get(k)
            try:
                if isinstance(v, str) and v.startswith("{") and v.endswith("}"):
                    maybe = json.loads(v)
                    pretty = json.dumps(maybe, indent=2)
                    print(f"{INDENT}{k}:")
                    for ln in pretty.splitlines():
                        print(INDENT*2 + ln)
                else:
                    s = str(v).replace("\\n", "\n")
                    for ln in s.splitlines():
                        for wrapped in textwrap.wrap(ln, WRAP_WIDTH):
                            print(INDENT + f"{k}: {wrapped}")
            except Exception:
                print(INDENT + f"{k}: {v}")

    if error_val:
        if isinstance(error_val, str):
            err_text = error_val.replace("\\n", "\n")
        else:
            err_text = str(error_val)
        print(INDENT + RED + "Error / Stacktrace:" + RESET)
        for ln in err_text.splitlines():
            if ln.strip() == "--- End of stack trace from previous location ---":
                print(INDENT + DIM + ln + RESET)
            else:
                wrapped = textwrap.wrap(ln, width=WRAP_WIDTH)
                if not wrapped:
                    print(INDENT*2 + "")
                else:
                    for w in wrapped:
                        print(INDENT*2 + w)
    print()

def build_ssh_command(remote, port, key, extra_ssh_args, docker_cmd):
    cmd = ["ssh", "-p", str(port)]
    if key:
        cmd += ["-i", key]
    if extra_ssh_args:
        cmd += extra_ssh_args.split()
    cmd += [remote, docker_cmd]
    return cmd

def run_process_and_stream(cmd_iterable, tz_name):
    process = None
    stream = None
    if isinstance(cmd_iterable, subprocess.Popen):
        process = cmd_iterable
        stream = process.stdout
    else:
        stream = cmd_iterable

    try:
        for raw in stream:
            try:
                if isinstance(raw, bytes):
                    line = raw.decode("utf-8", errors="replace").strip()
                else:
                    line = str(raw).strip()
                if not line:
                    continue
                obj = safe_json_load(line)
                if obj is None:
                    for ln in textwrap.wrap(line, width=WRAP_WIDTH):
                        print(INDENT + ln)
                    continue
                pretty_print_log(obj, tz_name)
            except KeyboardInterrupt:
                raise
            except Exception as e:
                print(f"Error processing line: {e}", file=sys.stderr)
                print(line)
    finally:
        if process:
            try:
                process.terminate()
            except Exception:
                pass

def start_local_docker(container, docker_args):
    if shutil.which("docker") is None:
        print("ERROR: `docker` not found on PATH.", file=sys.stderr)
        sys.exit(2)
    cmd = ["docker", "logs", "-f"]
    if docker_args:
        cmd += docker_args.split()
    cmd.append(container)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return proc

def start_remote_ssh(remote, port, key, extra_ssh_args, container, docker_args, use_sudo):
    docker_parts = []
    if use_sudo:
        docker_parts.append("sudo")
    docker_parts.append("docker")
    docker_parts.append("logs -f")
    if docker_args:
        docker_parts.append(docker_args)
    docker_parts.append(container)
    docker_cmd = " ".join(docker_parts)
    ssh_cmd = build_ssh_command(remote, port, key, extra_ssh_args, docker_cmd)
    proc = subprocess.Popen(ssh_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return proc

def main():
    args = parse_args()
    forced = args.force_color
    color_enabled = supports_color(forced)
    init_colors(color_enabled)

    tz_name = args.tz

    if args.stdin:
        if sys.stdin.isatty():
            print("Warning: --stdin used but stdin is a tty. Are you piping logs in?", file=sys.stderr)
        run_process_and_stream(sys.stdin, tz_name)
        return

    if not args.container:
        print("ERROR: container name required unless --stdin is used.", file=sys.stderr)
        sys.exit(2)

    if args.remote:
        if shutil.which("ssh") is None:
            print("ERROR: `ssh` client not found on PATH.", file=sys.stderr)
            sys.exit(2)
        attempt = 0
        while attempt <= args.retries:
            attempt += 1
            proc = None
            try:
                proc = start_remote_ssh(args.remote, args.ssh_port, args.ssh_key, args.ssh_args, args.container, args.docker_args, args.use_sudo)
                print(f"Connected to {args.remote} (attempt {attempt}). Streaming docker logs for container: {args.container}", file=sys.stderr)
                run_process_and_stream(proc, tz_name)
                if proc.poll() is None:
                    proc.wait(timeout=1)
                rc = proc.returncode
                print(f"SSH/docker process exited with code {rc}.", file=sys.stderr)
                if attempt > args.retries:
                    print("No more retries left — exiting.", file=sys.stderr)
                    break
                backoff = args.retry_backoff * (2 ** (attempt - 1))
                print(f"Reconnecting in {backoff:.1f}s (attempt {attempt}/{args.retries})...", file=sys.stderr)
                time.sleep(backoff)
                continue
            except KeyboardInterrupt:
                print("Interrupted by user.", file=sys.stderr)
                try:
                    if proc:
                        proc.terminate()
                except Exception:
                    pass
                break
            except Exception as e:
                print(f"Error starting/streaming remote logs: {e}", file=sys.stderr)
                if attempt > args.retries:
                    break
                backoff = args.retry_backoff * (2 ** (attempt - 1))
                print(f"Retrying in {backoff:.1f}s...", file=sys.stderr)
                time.sleep(backoff)
        return

    proc = start_local_docker(args.container, args.docker_args)
    try:
        run_process_and_stream(proc, tz_name)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()

