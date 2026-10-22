#!/usr/bin/env python3
"""Drives a real Helix (Steel build) through the CodeSnap commands in a pty.

Requires `hx` with Steel, `silicon`, and the ui-utils.hx cog installed. Uses a
throwaway configuration directory, so personal settings are never touched.
"""
import fcntl, os, pty, re, select, shutil, struct, sys, tempfile, termios, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run_helix(config_home, workdir, keys, settle=6.0):
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(workdir)
        os.environ.update(XDG_CONFIG_HOME=config_home, TERM="xterm-256color",
                          CODESNAP_CONFIG=os.path.join(workdir, "codesnap.toml"))
        os.execvp("hx", ["hx", "sample.rs"])
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    out = b""

    def pump(seconds):
        nonlocal out
        end = time.time() + seconds
        while time.time() < end:
            if select.select([fd], [], [], 0.1)[0]:
                try:
                    out += os.read(fd, 65536)
                except OSError:
                    return

    pump(2.5)
    for key in keys:
        os.write(fd, key.encode())
        pump(1.2)
    pump(settle)
    try:
        os.write(fd, b"\x1b:q!\r")
        pump(0.5)
        os.kill(pid, 9)
    except OSError:
        pass
    text = re.sub(rb"\x1b\[[0-9;?]*[a-zA-Z]|\x1b[()][A-Z0-9]", b" ", out).decode("utf8", "replace")
    return re.sub(r"\s+", " ", text)


def check(name, condition, screen):
    print(("ok   " if condition else "FAIL ") + name)
    if not condition:
        print(screen[-1200:])
        sys.exit(1)


def main():
    if not shutil.which("hx") or not shutil.which("silicon"):
        sys.exit("hx and silicon must be on PATH")
    with tempfile.TemporaryDirectory() as tmp:
        config = os.path.join(tmp, "xdg")
        work = os.path.join(tmp, "work")
        os.makedirs(os.path.join(config, "helix"))
        os.makedirs(work)
        with open(os.path.join(config, "helix", "helix.scm"), "w") as f:
            f.write(f'(require "{ROOT}/codesnap.scm")\n(require "{ROOT}/codesnap-menu.scm")\n'
                    "(provide codesnap codesnap-copy codesnap-save codesnap-doctor "
                    "codesnap-save-config codesnap-menu codesnap-reset)\n")
        with open(os.path.join(config, "helix", "init.scm"), "w") as f:
            f.write(";; Required for global Steel command registration by this Helix build.\n")
        with open(os.path.join(work, "sample.rs"), "w") as f:
            f.write('fn main() {\n    println!("hi");\n}\n')

        screen = run_helix(config, work, [":codesnap-doctor\r"])
        check("doctor reports silicon", "CodeSnap setup check" in screen and "silicon:" in screen, screen)

        run_helix(config, work, ["%", ":codesnap-save out.png\r"], settle=8.0)
        png = os.path.join(work, "out.png")
        check("capture writes a PNG", os.path.isfile(png) and open(png, "rb").read(8) == b"\x89PNG\r\n\x1a\n", "")

        screen = run_helix(config, work, [":codesnap-menu\r", "jjj", "\r", "j" * 13, "\r"])
        check("menu saves settings", os.path.isfile(os.path.join(work, "codesnap.toml")), screen)

        with open(os.path.join(work, "codesnap.toml"), "w") as f:
            f.write('theme = "Nord"\nshadow-blur = oops\n')
        screen = run_helix(config, work, [":codesnap-doctor\r"])
        check("bad saved values are reported, not fatal",
              "invalid value for shadow-blur" in screen, screen)
    print("CodeSnap smoke test: all checks passed")


if __name__ == "__main__":
    main()
