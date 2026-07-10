import machine
import utime
import ujson
from machine import UART, Pin
from Motor import PicoGo
from ws2812 import NeoPixel
from ST7789 import ST7789
from TRSensor import TRSensor

# ── швидкості 
LOW_SPEED    = 30
MEDIUM_SPEED = 50
HIGH_SPEED   = 80

# ── таймери
TELEMETRY_MS  = 3000
BT_TIMEOUT_MS = 12000

# ── пін-аут датчиків
US_TRIG_PIN  = 14
US_ECHO_PIN  = 15
IR_LEFT_PIN  = 3   
IR_RIGHT_PIN = 2  

# ── пороги режимів (см)
OBSTACLE_STOP_CM = 20
OBSTACLE_SLOW_CM = 35
FOLLOW_NEAR_CM   = 10
FOLLOW_FAR_CM    = 25

COLOR_OFF    = (0,   0,   0)
COLOR_FWD    = (80,  80,  0)   #     — рух вперед
COLOR_BWD    = (0,   80,  0)   #          — рух назад
COLOR_LEFT   = (0,   0,   80)  #          — поворот ліво
COLOR_RIGHT  = (0,   0,   80)  #           — поворот право
COLOR_WARN   = (40,  80,  0)   #       — сповільнення
COLOR_DANGER = (0,   80,  0)   #           — небезпека/стоп
COLOR_FOLLOW = (0,   0,   80)  #              — режим follow

LINE_MAX_POWER = 80
LINE_KP        = 1 / 30
LINE_KD        = 2

# ── стан ───────────────────────────────────────────────
speed               = MEDIUM_SPEED
mode                = "manual"
sensors_enabled     = True
manual_control      = False
bluetooth_connected = False
last_bt_ms          = 0
last_distance_cm    = 0.0
_us_last_ms         = 0    
obstacle_trigger    = ""
rx_buf              = b""
pid_last_err        = 0
trs_calibrated      = False
lcd_active          = False

bat      = machine.ADC(Pin(26))
temp_adc = machine.ADC(4)

us_trig = Pin(US_TRIG_PIN, Pin.OUT)
us_echo = Pin(US_ECHO_PIN, Pin.IN)
us_trig.low()

ir_left  = Pin(IR_LEFT_PIN,  Pin.IN)
ir_right = Pin(IR_RIGHT_PIN, Pin.IN)

lcd   = ST7789()
motor = PicoGo()
uart  = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
led   = Pin(25, Pin.OUT)
buz   = Pin(4,  Pin.OUT)
strip = NeoPixel()
trs   = TRSensor()

led.value(1)
buz.value(0)
for _i in range(4):
    strip.pixels_set(_i, COLOR_OFF)
strip.pixels_show()

def rgb_all(color):
    for i in range(4):
        strip.pixels_set(i, color)
    strip.pixels_show()

def rgb_sides(left_color, right_color):
    strip.pixels_set(0, left_color)
    strip.pixels_set(1, left_color)
    strip.pixels_set(2, right_color)
    strip.pixels_set(3, right_color)
    strip.pixels_show()

def rgb_off():
    rgb_all(COLOR_OFF)


def send_json(obj):
    uart.write(ujson.dumps(obj) + "\n")


def splash():
    lcd.fill(0x0010)
    lcd.rect(4, 4, 232, 130, 0x051F)
    lcd.rect(6, 6, 228, 126, 0x07BF)
    lcd.fill_rect(6, 6, 228, 18, 0x051F)
    lcd.text("PicoGo  Raspberry Pi Pico", 8, 10, 0x07FF)
    lcd.line(6, 24, 233, 24, 0x07BF)
    lcd.text("v2.0  ready", 80, 96, 0xFFFF)
    lcd.text("Waveshare.com", 72, 116, 0x07E0)
    lcd.show()


def on_bt_activity():
    global bluetooth_connected, last_bt_ms, lcd_active
    last_bt_ms = utime.ticks_ms()
    if not bluetooth_connected:
        bluetooth_connected = True
        if not lcd_active:
            lcd_active = True
            splash()
            utime.sleep_ms(800)
        send_json({"Ready": 1, "State": "BT"})

def bt_timeout_check():
    global bluetooth_connected
    if not bluetooth_connected:
        return
    if utime.ticks_diff(utime.ticks_ms(), last_bt_ms) > BT_TIMEOUT_MS:
        bluetooth_connected = False
        motor.stop()
        rgb_off()
        lcd.fill(0x0000)
        lcd.show()


def measure_distance_cm():
    global last_distance_cm, _us_last_ms
    now = utime.ticks_ms()
    if utime.ticks_diff(now, _us_last_ms) < 60:
        return last_distance_cm          # ще рано — повертаємо кеш
    _us_last_ms = now
    us_trig.low()
    utime.sleep_us(2)
    us_trig.high()
    utime.sleep_us(10)
    us_trig.low()
    pulse_us = machine.time_pulse_us(us_echo, 1, 30000)
    if pulse_us < 0:
        return last_distance_cm
    dist = pulse_us * 0.0343 / 2
    if dist < 2 or dist > 400:
        return last_distance_cm
    last_distance_cm = dist
    return dist

def read_sensors():
    reading     = temp_adc.read_u16() * 3.3 / 65535
    temperature = 27 - (reading - 0.706) / 0.001721
    v   = bat.read_u16() * 3.3 / 65535 * 2
    p   = max(0.0, min(100.0, (v - 3.5) * 100.0 / 0.7))
    if sensors_enabled:
        distance = measure_distance_cm()
        ol  = 1 if ir_left.value()  == 0 else 0
        orr = 1 if ir_right.value() == 0 else 0
    else:
        distance, ol, orr = 0.0, 0, 0
    return {
        "temperature":    round(temperature, 2),
        "Voltage":        round(v, 2),
        "percent":        round(p, 1),
        "Distance":       round(distance, 1),
        "obstacle_left":  ol,
        "obstacle_right": orr,
    }



def _bar_color565(pct):
    if   pct >= 75: return 0x07E0
    elif pct >= 50: return 0xFFE0
    elif pct >= 25: return 0xFC60
    else:           return 0xF800

def draw_bar(x, y, w, h, pct, bg=0x2104):
    lcd.rect(x - 1, y - 1, w + 2, h + 2, 0x8410)
    lcd.fill_rect(x, y, w, h, bg)
    filled = int(w * pct / 100)
    if filled > 0:
        color = _bar_color565(pct)
        lcd.fill_rect(x, y, filled, h, color)
        lcd.line(x, y,     x + filled - 1, y,     0xFFFF)
        lcd.line(x, y + 1, x + filled - 1, y + 1, 0xC618)

def large_text(s, x, y, color):
    import framebuf
    buf = bytearray(len(s) * 8 * 8 * 2)
    fb  = framebuf.FrameBuffer(buf, len(s) * 8, 8, framebuf.RGB565)
    fb.fill(0)
    fb.text(s, 0, 0, 0xFFFF)
    for row in range(8):
        for col in range(len(s) * 8):
            idx   = (row * len(s) * 8 + col) * 2
            pixel = buf[idx] | (buf[idx + 1] << 8)
            if pixel:
                lcd.fill_rect(x + col * 2, y + row * 2, 2, 2, color)

def _draw_ir_dot(x, y, pin_val):
    color = 0x07E0 if pin_val else 0xF800
    lcd.fill_rect(x, y, 10, 10, color)
    lcd.rect(x, y, 10, 10, 0xFFFF)

def draw_lcd(data):
    pct  = int(data["percent"])
    dist = data["Distance"]
    ol   = data["obstacle_left"]
    orr  = data["obstacle_right"]

    lcd.fill(0x0010)

    bt_label = "BT:ON" if bluetooth_connected else "BT:--"
    lcd.fill_rect(0, 0, 240, 14, 0x051F)
    lcd.text(bt_label, 4,   2, 0x07FF)
    lcd.text(mode,     90,  2, 0xFFE0)
    lcd.text("S:" + str(speed), 172, 2, 0x07E0)

    lcd.text("BAT", 4, 18, 0xC618)
    draw_bar(36, 18, 160, 10, pct)
    lcd.text(str(pct) + "%", 200, 18, _bar_color565(pct))

    lcd.line(0, 32, 239, 32, 0x2945)
    lcd.text("TEMP", 4,   36, 0xC618)
    lcd.text("{:5.1f}C".format(data["temperature"]), 48, 36, 0xFFFF)
    lcd.text("VOLT", 130, 36, 0xC618)
    lcd.text("{:4.2f}V".format(data["Voltage"]), 170, 36, 0xFFFF)

    lcd.line(0, 48, 239, 48, 0x2945)
    lcd.text("DIST", 4, 52, 0xC618)
    dist_color = 0xF800 if dist < OBSTACLE_STOP_CM else (0xFC60 if dist < OBSTACLE_SLOW_CM else 0x07E0)
    lcd.text("{:5.1f}cm".format(dist), 44, 52, dist_color)
    draw_bar(140, 54, 94, 8, min(100, int(dist)), 0x2104)

    lcd.line(0, 66, 239, 66, 0x2945)
    lcd.text("IR-L", 4,  70, 0xC618)
    _draw_ir_dot(40,  70, ir_left.value())
    lcd.text("IR-R", 80, 70, 0xC618)
    _draw_ir_dot(116, 70, ir_right.value())

    lcd.line(0, 84, 239, 84, 0x2945)
    if obstacle_trigger:
        lcd.fill_rect(0, 86, 240, 30, 0x4000)
        lcd.text("! " + obstacle_trigger + " !", 4, 96, 0xFBE0)
    else:
        labels = {
            "manual":   "MANUAL",
            "obstacle": "OBSTACLE",
            "follow":   "FOLLOW",
            "line":     "LINE",
            "idle":     "IDLE",
        }
        lbl = labels.get(mode, mode.upper())
        lbl_w = len(lbl) * 16
        lbl_x = max(4, (240 - lbl_w) // 2)
        large_text(lbl, lbl_x, 88, 0x07FF)

    if mode == "line":
        trs_label = "TRS:OK" if trs_calibrated else "TRS:CAL"
        trs_color = 0x07E0 if trs_calibrated else 0xFC60
        lcd.text(trs_label, 4, 112, trs_color)

    lcd.show()


_obs_state    = "clear"
_obs_state_ts = 0
_obs_turn_dir = "right"

def run_obstacle_mode():
    global obstacle_trigger, _obs_state, _obs_state_ts, _obs_turn_dir, manual_control

    now  = utime.ticks_ms()

    if _obs_state == "backup":
        manual_control = False         
        motor.backward(MEDIUM_SPEED)
        rgb_all(COLOR_BWD)
        obstacle_trigger = "BACKING UP"
        if utime.ticks_diff(now, _obs_state_ts) >= 400:
            motor.stop()
            _obs_state    = "turn"
            _obs_state_ts = now
        return

    if _obs_state == "turn":
        manual_control = False        
        if _obs_turn_dir == "right":
            motor.right(40)
            rgb_sides(COLOR_OFF, COLOR_RIGHT)
        else:
            motor.left(40)
            rgb_sides(COLOR_LEFT, COLOR_OFF)
        obstacle_trigger = "TURNING"
        if utime.ticks_diff(now, _obs_state_ts) >= 500:
            motor.stop()
            rgb_off()
            _obs_state       = "clear"
            obstacle_trigger = ""
        return

    dist = measure_distance_cm()

    if dist < OBSTACLE_STOP_CM:
        l = ir_left.value()
        r = ir_right.value()
        _obs_turn_dir = "left" if (r == 0 and l == 1) else "right"
        motor.stop()
        rgb_all(COLOR_DANGER)
        obstacle_trigger = "STOP {:.0f}cm".format(dist)
        _obs_state    = "backup"
        _obs_state_ts = now
    elif dist < OBSTACLE_SLOW_CM:
        obstacle_trigger = "SLOW {:.0f}cm".format(dist)
        rgb_all(COLOR_WARN)
    else:
        obstacle_trigger = ""

def run_follow_mode():
    global obstacle_trigger
    dist = measure_distance_cm()
    l = ir_left.value()
    r = ir_right.value()

    if dist < FOLLOW_NEAR_CM:
        motor.stop()
        obstacle_trigger = "TOO CLOSE"
        rgb_all(COLOR_DANGER)
    elif l == 0 and r == 1:
        motor.left(20)
        obstacle_trigger = ""
        rgb_sides(COLOR_LEFT, COLOR_OFF)
    elif l == 1 and r == 0:
        motor.right(20)
        obstacle_trigger = ""
        rgb_sides(COLOR_OFF, COLOR_RIGHT)
    elif FOLLOW_NEAR_CM <= dist < FOLLOW_FAR_CM:
        motor.forward(LOW_SPEED)
        obstacle_trigger = "FOLLOW"
        rgb_all(COLOR_FOLLOW)
    else:
        motor.stop()
        obstacle_trigger = ""
        rgb_all(COLOR_FWD)


def calibrate_trs():
    global trs_calibrated, pid_last_err
    lcd.fill(0x0010)
    lcd.fill_rect(0, 0, 240, 14, 0x4000)
    lcd.text("CALIBRATION...", 40, 2, 0xFFFF)
    lcd.text("Робот обертається для", 4, 30, 0xC618)
    lcd.text("зчитування контрасту.", 4, 46, 0xC618)
    lcd.show()
    for i in range(100):
        if i < 25 or i >= 75:
            motor.setMotor(30, -30)
        else:
            motor.setMotor(-30, 30)
        trs.calibrate()
    motor.stop()
    pid_last_err   = 0
    trs_calibrated = True
    lcd.fill(0x0010)
    lcd.fill_rect(0, 0, 240, 14, 0x051F)
    lcd.text("CALIBRATION DONE", 28, 2, 0x07FF)
    lcd.text("Min: " + str(trs.calibratedMin), 4, 30, 0xFFFF)
    lcd.text("Max: " + str(trs.calibratedMax), 4, 46, 0xFFFF)
    lcd.show()
    utime.sleep_ms(1500)
    send_json({"State": "TRS:calibrated"})


def run_line_mode():
    global obstacle_trigger, pid_last_err

    if not trs_calibrated:
        motor.stop()
        obstacle_trigger = "NEED CALIB"
        return

    position, sensors = trs.readLine()
    total = sum(sensors)

    if total > 4000:
        motor.stop()
        obstacle_trigger = "LINE LOST"
        rgb_all(COLOR_DANGER)
        return

    l = ir_left.value()
    r = ir_right.value()
    if l == 0 or r == 0:
        buz.value(1)
        motor.stop()
        obstacle_trigger = "IR OBSTACLE"
        rgb_all(COLOR_DANGER)
        utime.sleep_ms(100)
        buz.value(0)
        return
    buz.value(0)

    proportional = position - 2000
    derivative   = proportional - pid_last_err
    pid_last_err = proportional
    power_diff   = proportional * LINE_KP + derivative * LINE_KD
    power_diff   = max(-LINE_MAX_POWER, min(LINE_MAX_POWER, power_diff))

    COLOR_LINE_ON  = (80, 0, 0)   # зелений — на лінії
    COLOR_LINE_OFF = (0, 0, 0)    # вимкнено

    if power_diff < 0:
        motor.setMotor(int(LINE_MAX_POWER + power_diff), LINE_MAX_POWER)
        rgb_sides(COLOR_WARN, COLOR_LINE_ON)
    else:
        motor.setMotor(LINE_MAX_POWER, int(LINE_MAX_POWER - power_diff))
        rgb_sides(COLOR_LINE_ON, COLOR_WARN)

    obstacle_trigger = ""


def handle_command(j):
    global speed, mode, sensors_enabled, manual_control, obstacle_trigger
    global _obs_state, _obs_state_ts

    if j.get("Ping") is not None:
        send_json({"Pong": 1})
        return

    cmd = j.get("Mode")
    if cmd in ("manual", "obstacle", "follow", "line", "idle"):
        mode             = cmd
        manual_control   = False
        obstacle_trigger = ""
        _obs_state       = "clear"
        _obs_state_ts    = utime.ticks_ms()
        motor.stop()
        rgb_off()
        if cmd == "line" and not trs_calibrated:
            calibrate_trs()
        send_json({"State": "Mode:" + cmd})
        return

    if j.get("Calibrate") == "line":
        calibrate_trs()
        send_json({"State": "TRS:done"})
        return

    cmd = j.get("Sensors")
    if cmd is not None:
        sensors_enabled = (cmd == "on")
        send_json({"State": "Sensors:" + cmd})
        return


    cmd = j.get("Forward")
    if cmd is not None:
        if cmd == "Down":
            if mode == "obstacle" and _obs_state != "clear":
                return
            manual_control = True
            motor.forward(speed)
            rgb_all(COLOR_FWD)
            send_json({"State": "Forward"})
        else:
            manual_control = False
            motor.stop()
            rgb_off()
            send_json({"State": "Stop"})
        return

    cmd = j.get("Backward")
    if cmd is not None:
        if cmd == "Down":
            if mode == "obstacle" and _obs_state != "clear":
                return
            manual_control = True
            motor.backward(speed)
            rgb_all(COLOR_BWD)
            send_json({"State": "Backward"})
        else:
            manual_control = False
            motor.stop()
            rgb_off()
            send_json({"State": "Stop"})
        return

    cmd = j.get("Left")
    if cmd is not None:
        if cmd == "Down":
            if mode == "obstacle" and _obs_state != "clear":
                return
            manual_control = True
            motor.left(20)
            rgb_sides(COLOR_LEFT, COLOR_OFF)
            send_json({"State": "Left"})
        else:
            manual_control = False
            motor.stop()
            rgb_off()
            send_json({"State": "Stop"})
        return

    cmd = j.get("Right")
    if cmd is not None:
        if cmd == "Down":
            if mode == "obstacle" and _obs_state != "clear":
                return
            manual_control = True
            motor.right(20)
            rgb_sides(COLOR_OFF, COLOR_RIGHT)
            send_json({"State": "Right"})
        else:
            manual_control = False
            motor.stop()
            rgb_off()
            send_json({"State": "Stop"})
        return

    for key, val in (("Low", LOW_SPEED), ("Medium", MEDIUM_SPEED), ("High", HIGH_SPEED)):
        if j.get(key) == "Down":
            speed = val
            send_json({"State": key})
            return

    bz = j.get("BZ")
    if bz == "on":  buz.value(1); send_json({"BZ": "ON"});  return
    if bz == "off": buz.value(0); send_json({"BZ": "OFF"}); return

    lv = j.get("LED")
    if lv == "on":  led.value(1); send_json({"LED": "ON"});  return
    if lv == "off": led.value(0); send_json({"LED": "OFF"}); return

    rv = j.get("RGB")
    if rv is not None:
        try:
            rgb_all(tuple(eval(rv)))
            send_json({"State": "RGB"})
        except Exception:
            pass
        return


    global rx_buf
    while uart.any():
        chunk = uart.read()
        if not chunk:
            break
        on_bt_activity()
        if isinstance(chunk, int):
            chunk = bytes([chunk])
        rx_buf += chunk

    while True:
        nl = rx_buf.find(b"\n")
        if nl >= 0:
            line   = rx_buf[:nl]
            rx_buf = rx_buf[nl + 1:]
        else:
            s = rx_buf.find(b"{")
            e = rx_buf.find(b"}")
            if s >= 0 and e > s:
                line   = rx_buf[s:e + 1]
                rx_buf = rx_buf[e + 1:]
            else:
                break
        if not line:
            continue
        try:
            text = line.decode("utf-8").strip()
        except Exception:
            text = str(line).strip()
        if not text or text[0] != "{":
            continue
        try:
            j = ujson.loads(text)
        except Exception:
            continue
        if "temperature" in j or "Voltage" in j or "percent" in j:
            continue
        handle_command(j)


lcd.fill(0x0000)
lcd.show()

t_telem = utime.ticks_ms()
t_bt    = utime.ticks_ms()
t_auto  = utime.ticks_ms()

OBSTACLE_INTERVAL_MS = 80    
FOLLOW_INTERVAL_MS   = 100
LINE_INTERVAL_MS     = 30
IR_DISPLAY_MS        = 100   

t_ir = utime.ticks_ms()

while True:
    process_uart()

    now = utime.ticks_ms()

    if utime.ticks_diff(now, t_bt) >= 500:
        bt_timeout_check()
        t_bt = now

    if mode == "obstacle" and utime.ticks_diff(now, t_auto) >= OBSTACLE_INTERVAL_MS:
        run_obstacle_mode()
        t_auto = now

    elif not manual_control:
        if mode == "follow" and utime.ticks_diff(now, t_auto) >= FOLLOW_INTERVAL_MS:
            run_follow_mode()
            t_auto = now
        elif mode == "line" and utime.ticks_diff(now, t_auto) >= LINE_INTERVAL_MS:
            run_line_mode()
            t_auto = now

    if lcd_active and utime.ticks_diff(now, t_ir) >= IR_DISPLAY_MS:
        _draw_ir_dot(40,  70, ir_left.value())
        _draw_ir_dot(116, 70, ir_right.value())
        lcd.show()
        t_ir = now

    if utime.ticks_diff(now, t_telem) >= TELEMETRY_MS:
        data = read_sensors()
        if lcd_active:
            draw_lcd(data)
        payload = dict(data)
        payload["mode"]            = mode
        payload["speed"]           = speed
        payload["sensors_enabled"] = 1 if sensors_enabled else 0
        payload["bt_connected"]    = 1 if bluetooth_connected else 0
        payload["trs_calibrated"]  = 1 if trs_calibrated else 0
        if obstacle_trigger:
            payload["obstacle_trigger"] = obstacle_trigger
        send_json(payload)
        t_telem = now

    utime.sleep_ms(5)
