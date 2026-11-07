# linux-minimal (fase 1) - Coolpad Arise 5560S

Arranca el kernel stock 3.4 con un initramfs de BusyBox. **Sin Android, sin TWRP.**
Objetivo de la fase 1: ver que (1) enciende la pantalla, (2) hay enlace USB y (3) hay shell.

> **No probado en el teléfono.** Todo se verificó solo por estructura (cabecera del
> boot image, kernel y dt.img idénticos a `prebuilt/`, cpio válido, lógica de las barras).

## Construir

    python3 linux-minimal/pack.py        # -> linux-minimal/out/linux-minimal.img (~5.9 MB)

Descarga BusyBox 1.31 estático ARMv7 y verifica su SHA-256. No necesita cpio ni mkbootimg.

## Probar (de menos a más riesgo)

1. **Sin flashear:** `fastboot boot linux-minimal/out/linux-minimal.img` (si el bootloader lo permite).
2. **Flashear en recovery**, no en boot, para dejar Android intacto. Antes, saca una copia:
   `adb shell dd if=/dev/block/mmcblk0p19 of=/sdcard/recovery-backup.img` y cópiala a tu PC.
   Luego `fastboot flash recovery linux-minimal/out/linux-minimal.img`.
   Para volver a TWRP, flashea ese backup.
3. Nunca flashees en `boot` (p10) sin backup de boot.

## Qué verás en pantalla

El kernel no tiene VT/fbcon, así que `/init` pinta barras en `/dev/fb0` (una por etapa):

| Barra | Etapa | Verde = OK, gris = falló |
|---|---|---|
| 1 (arriba) | framebuffer encontrado (32 bpp) | |
| 2 | backlight encendido | |
| 3 | eMMC visible | |
| 4 | dispositivos de entrada | |
| 5 | red USB (rndis) levantada | |
| 6 | telnetd activo | |
| 8 (abajo) | `/init` terminó | |

Si la pantalla no enciende pero hay barras apagadas, el backlight es el sospechoso
(`/sys/class/leds/*`).

## Shell por USB

Si el kernel soporta RNDIS, el teléfono queda en `192.168.7.2`. En tu PC pon una IP
estática `192.168.7.1/24` en la interfaz nueva y haz `telnet 192.168.7.2`.
**telnetd no tiene contraseña** (solo accesible por el cable USB). Para las fases
siguientes se cambia por SSH. Log del arranque: `cat /init.log`.

## Limitaciones conocidas del kernel (de su config embebida)

- Sin `CONFIG_DEVTMPFS`: `/init` monta tmpfs en `/dev` y usa `mdev -s`.
- Sin VT/fbcon: la UI futura dibuja directo en `/dev/fb0` con CPU.
- GPU solo por KGSL (sin DRM): sin aceleración.
- No se sabe si trae RNDIS; si la barra 5 sale gris, usar otra función USB (hay que probar).
