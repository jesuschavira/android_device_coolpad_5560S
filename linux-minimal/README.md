# linux-minimal (fases 1 y 2) - Coolpad Arise 5560S

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
| 7 | rootfs de Alpine montado desde la SD (fase 2) | gris = no se encontró, se queda en el shell de la fase 1 |
| 8 (abajo) | `/init` terminó (solo si no hubo cambio a Alpine) | |

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

## Fase 2: Alpine desde la tarjeta SD

El initramfs busca `alpine.img` en la raíz de la SD (`mmcblk1p1`, FAT32), la monta con loop
y hace `switch_root`. **No toca ninguna partición interna.** Si no hay SD, imagen o rootfs,
se queda en el shell de la fase 1 (barra 7 gris).

Construir (necesita `curl`, `tar`, `mke2fs` >= 1.43, `openssl`; como root o con `fakeroot`):

    ./linux-minimal/build-alpine.sh --pubkey ~/.ssh/id_ed25519.pub
    # sin --pubkey ni --password genera una contraseña aleatoria y la imprime una vez

Genera `out/alpine.img` (ext4 de 256 MB, `--size MB` para cambiarlo): Alpine 3.24.4 armv7
(SHA-256 verificado) + dropbear + `apk` apuntando a los repos de Alpine. Copia ese archivo
a la raíz de la SD y reconstruye/flashea `linux-minimal.img` con `pack.py` (el `init` cambió).

Con `--pubkey` el SSH queda **solo con clave** (sin contraseña). Conexión por el cable USB:

    # IP estática 192.168.7.1/24 en la interfaz USB de tu PC
    ssh root@192.168.7.2

Sin OpenRC: usa el `init` de BusyBox con `/etc/inittab` y `/etc/boot.sh` (ver `alpine/`).
Servicios extra: se añaden en `boot.sh` / `inittab`.

### Verificado / no verificado

- Verificado en el contenedor: la imagen pasa `e2fsck`, los propietarios son root, y los binarios
  ARM (busybox, apk, dropbear) ejecutan bajo `qemu-arm-static`. El kernel stock trae
  ext4, vfat, loop, VFP/NEON/AEABI/Thumb y pseudo-terminales.
- **No verificado en el teléfono:** que la SD se vea como `mmcblk1p1`, que RNDIS exista y
  que dropbear acepte conexiones. Sin WiFi todavía (necesita firmware del Android stock).
