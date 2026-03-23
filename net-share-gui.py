#!/usr/bin/env python3
"""
NetShare cross-platform GUI (macOS / Linux)
Replaces net-share.ps1 on non-Windows platforms.

Usage:
  net-share-gui.py share <file_or_folder>
  net-share-gui.py receive
"""
import sys
import os
import socket
import subprocess
import threading
import tkinter as tk
from tkinter import font as tkfont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVER_PY  = os.path.join(SCRIPT_DIR, "server.py")
DROP_DIR   = os.path.join(os.path.expanduser("~"), "Downloads", "received")

# ── Palette ───────────────────────────────────────────────────────────────────
C_BG    = "#1c1c1e"
C_CARD  = "#2c2c2e"
C_TEAL  = "#50c8a0"
C_WHITE = "#ffffff"
C_DIM   = "#888888"
C_SEP   = "#3a3a3c"
C_BTN   = "#3a3a3c"


def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


def find_free_port():
    for p in range(8080, 8100):
        with socket.socket() as s:
            try:
                s.bind(("", p))
                return p
            except OSError:
                pass
    return 8080


class NetShareWindow(tk.Tk):
    def __init__(self, mode, path):
        super().__init__()
        self._mode   = mode   # "share" or "receive"
        self._path   = path
        self._server = None
        self._port   = find_free_port()
        self._ip     = get_local_ip()
        self._url    = f"http://{self._ip}:{self._port}"

        self.title("NetShare")
        self.configure(bg=C_BG)
        self.resizable(False, False)
        self.protocol("WM_DELETE_WINDOW", self._stop)

        self._build()

        W, H = 320, 430
        self.update_idletasks()
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        self.geometry(f"{W}x{H}+{(sw - W) // 2}+{(sh - H) // 2}")

        self._start_server()

    # ── UI ────────────────────────────────────────────────────────────────────

    def _build(self):
        f_title = tkfont.Font(family="Consolas", size=16, weight="bold")
        f_sub   = tkfont.Font(family="Consolas", size=8)
        f_url   = tkfont.Font(family="Consolas", size=9)
        f_btn   = tkfont.Font(family="Consolas", size=9, weight="bold")

        tk.Frame(self, bg=C_BG, height=20).pack()

        tk.Label(self, text="NetShare", font=f_title, bg=C_BG, fg=C_TEAL).pack()

        if self._mode == "share":
            label = os.path.basename(self._path)
        else:
            label = "receiving files"
        tk.Label(self, text=label, font=f_sub, bg=C_BG, fg=C_DIM).pack(pady=(4, 14))

        # QR code placeholder — populated asynchronously
        self._qr_frame = tk.Frame(self, bg=C_WHITE, width=180, height=180)
        self._qr_frame.pack()
        self._qr_frame.pack_propagate(False)
        self._qr_lbl = tk.Label(self._qr_frame, text="generating QR...",
                                bg=C_WHITE, fg="#999999", font=f_sub)
        self._qr_lbl.place(relx=0.5, rely=0.5, anchor="center")

        tk.Frame(self, bg=C_BG, height=10).pack()

        # Clickable URL
        url_lbl = tk.Label(self, text=self._url, font=f_url, bg=C_BG, fg=C_TEAL,
                           cursor="hand2")
        url_lbl.pack()
        url_lbl.bind("<Button-1>", lambda _: self._open_browser())

        tk.Frame(self, bg=C_BG, height=4).pack()

        self._status_var = tk.StringVar(value="starting server...")
        tk.Label(self, textvariable=self._status_var, font=f_sub,
                 bg=C_BG, fg=C_DIM).pack()

        tk.Frame(self, bg=C_BG, height=14).pack()
        tk.Frame(self, bg=C_SEP, height=1).pack(fill="x", padx=28)
        tk.Frame(self, bg=C_BG, height=14).pack()

        tk.Button(
            self, text="STOP  ✕", font=f_btn,
            bg=C_BTN, fg=C_WHITE,
            activebackground=C_TEAL, activeforeground="#000000",
            relief="flat", bd=0, padx=24, pady=9, cursor="hand2",
            command=self._stop,
        ).pack()

    # ── Server ────────────────────────────────────────────────────────────────

    def _start_server(self):
        serve_path = self._path if self._mode == "share" else \
                     os.path.expanduser("~/Downloads")
        os.makedirs(DROP_DIR, exist_ok=True)

        self._server = subprocess.Popen(
            [sys.executable, SERVER_PY, serve_path, str(self._port), DROP_DIR],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        threading.Thread(target=self._wait_ready, daemon=True).start()

    def _wait_ready(self):
        if not self._server or not self._server.stdout:
            return
        line = self._server.stdout.readline().decode().strip()
        if line.startswith("READY:"):
            self.after(0, self._on_ready)

    def _on_ready(self):
        self._status_var.set(f"live on port {self._port}  —  open on any device")
        self._open_browser()
        self._try_generate_qr()

    def _open_browser(self):
        if sys.platform == "darwin":
            subprocess.run(["open", self._url])
        else:
            subprocess.run(["xdg-open", self._url])

    # ── QR code ───────────────────────────────────────────────────────────────

    def _try_generate_qr(self):
        threading.Thread(target=self._generate_qr, daemon=True).start()

    def _generate_qr(self):
        try:
            import qrcode
            from PIL import Image, ImageTk
            img = qrcode.make(self._url).resize((170, 170))
            photo = ImageTk.PhotoImage(img)
            self.after(0, lambda: self._show_qr(photo))
        except ImportError:
            self.after(0, lambda: self._qr_lbl.config(
                text="scan on phone:\n" + self._url.replace("http://", ""),
                font=tkfont.Font(family="Consolas", size=7),
            ))

    def _show_qr(self, photo):
        self._qr_lbl.config(image=photo, text="")
        self._qr_lbl.image = photo  # prevent GC

    # ── Teardown ──────────────────────────────────────────────────────────────

    def _stop(self):
        if self._server:
            self._server.terminate()
        self.destroy()


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("share", "receive"):
        print("Usage: net-share-gui.py share <path>  |  net-share-gui.py receive")
        sys.exit(1)

    mode = sys.argv[1]
    path = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/Downloads")

    if mode == "share" and not os.path.exists(path):
        print(f"Path not found: {path}")
        sys.exit(1)

    app = NetShareWindow(mode, path)
    app.mainloop()
